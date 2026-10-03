import { NestFactory } from '@nestjs/core';
import { WebSocketGateway, WebSocketServer, SubscribeMessage, MessageBody, ConnectedSocket } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { EventEmitter } from 'events';
import { Module, Controller, Get, Post, Patch, Body, Param, Headers, Query, Delete, Req, BadRequestException, NotFoundException, UnauthorizedException, ForbiddenException, ConflictException, ServiceUnavailableException, HttpException, Catch, ArgumentsHost, ExceptionFilter, Injectable } from '@nestjs/common';
import { Pool, PoolClient } from 'pg';
import { randomUUID, createHmac, createHash } from 'crypto';
import { IntegrationService } from './integrations';
import { API_VERSION, ORDER_TRANSITIONS, distanceKm, deliveryFee } from './domain';

const JWT_SECRET = process.env.JWT_SECRET || '';
if (process.env.NODE_ENV === 'production' && JWT_SECRET.length < 32) throw new Error('JWT_SECRET must be at least 32 characters in production');
const REFRESH_TOKEN_TTL_DAYS = Number(process.env.REFRESH_TOKEN_TTL_DAYS || 30);
const RATE_LIMIT_WINDOW_MS = Number(process.env.RATE_LIMIT_WINDOW_MS || 60000);
const RATE_LIMIT_MAX = Number(process.env.RATE_LIMIT_MAX || 120);
const rateBuckets = new Map<string,{start:number,count:number}>();
function hashToken(v:string){ return createHash('sha256').update(v).digest('hex'); }
function signToken(payload:any){ const body=Buffer.from(JSON.stringify({...payload,exp:Math.floor(Date.now()/1000)+Number(process.env.ACCESS_TOKEN_TTL_SECONDS||3600)})).toString('base64url'); const sig=createHmac('sha256',JWT_SECRET).update(body).digest('base64url'); return `${body}.${sig}`; }
function verifyToken(token:string){
  try{
    const [body,sig]=String(token||'').split('.');
    if(!body||!sig)return null;
    const expected=createHmac('sha256',JWT_SECRET).update(body).digest('base64url');
    const a=Buffer.from(String(sig),'utf8'), b=Buffer.from(String(expected),'utf8');
    if(a.length!==b.length || !require('crypto').timingSafeEqual(a,b))return null;
    const p=JSON.parse(Buffer.from(body,'base64url').toString());
    if(!p?.sub || Number(p.exp||0)<Date.now()/1000)return null;
    return p;
  }catch{return null;}
}
const API_ALLOWED_ORIGINS = String(process.env.CORS_ORIGINS || '').split(',').map(x=>x.trim()).filter(Boolean);
const isProduction = process.env.NODE_ENV === 'production';
if (isProduction && JWT_SECRET.length < 32) throw new Error('JWT_SECRET must be at least 32 characters in production');
function finiteNumber(value:any){ const n=Number(value); return Number.isFinite(n) ? n : null; }
function validUuid(v:any){ return typeof v==='string' && /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$/.test(v); }
function validLatLon(lat:any, lon:any){ const a=finiteNumber(lat), b=finiteNumber(lon); return a!==null && b!==null && a>=-90 && a<=90 && b>=-180 && b<=180; }
function boundedText(value:any, max:number){ const s=String(value ?? '').trim(); return s.length<=max ? s : s.slice(0,max); }
const BRAND = { name:'جايك', latin:'JAYEK', tagline:'طلبك جايك .. كل اللي محتاجه لحد بابك', colors:{primary:'#176B4D',secondary:'#65B87A',accent:'#F39A3D',background:'#FFF8EA',text:'#202522'} };
const SERVICES = ['FOOD','GROCERY','PHARMACY','STORES','VEGETABLES','BUTCHERY','BAKERY'];
const TRANSITIONS = ORDER_TRANSITIONS;

const realtime = new EventEmitter();
const NOTIFICATION_COPY:any = {
  CREATED: ['تم استلام طلبك','طلبك اتسجل عند المتجر وجاري مراجعته.'],
  ACCEPTED_BY_MERCHANT: ['المتجر قبل طلبك','المتجر بدأ تجهيز طلبك.'],
  PREPARING: ['طلبك بيتجهز','المتجر بيجهز طلبك الآن.'],
  READY_FOR_PICKUP: ['طلبك جاهز','طلبك جاهز للاستلام من الكابتن.'],
  ASSIGNED_RIDER: ['الكابتن اتعيّن','كابتن جايك استلم مهمة طلبك.'],
  PICKED_UP: ['طلبك خرج من المتجر','الكابتن استلم طلبك.'],
  ON_THE_WAY: ['طلبك في الطريق','الكابتن في الطريق إليك.'],
  DELIVERED: ['تم توصيل طلبك','طلبك وصل. بالهنا والشفا!'],
  REJECTED: ['تعذر تنفيذ الطلب','المتجر اعتذر عن تنفيذ الطلب.'],
  CANCELLED: ['تم إلغاء الطلب','تم إلغاء طلبك.'],
  PAYMENT_FAILED: ['فشل الدفع','لم تتم عملية الدفع بنجاح.']
};

@Injectable()
class Db {
  pool = new Pool({ connectionString:process.env.DATABASE_URL || 'postgresql://jayek:jayek_dev_password@localhost:5432/jayek' });
  query<T=any>(text:string, params:any[]=[]){ return this.pool.query<T>(text,params); }
  async tx<T>(fn:(c:PoolClient)=>Promise<T>):Promise<T>{ const c=await this.pool.connect(); try{await c.query('BEGIN'); const r=await fn(c); await c.query('COMMIT'); return r;}catch(e){await c.query('ROLLBACK');throw e;}finally{c.release();} }
}

@Controller()
class AppController {
  private otpAttempts = new Map<string,{start:number,count:number}>();
  constructor(private db:Db, private integrations:IntegrationService){}
  @Get('notifications') async notifications(@Headers() h:any,@Query('unread') unread?:string){ const userId=this.userId(h); const filter=unread==='true'?' AND read_at IS NULL':''; return (await this.db.query(`SELECT * FROM notifications WHERE user_id=$1${filter} ORDER BY created_at DESC LIMIT 100`,[userId])).rows; }
  @Get('notifications/unread-count') async unreadCount(@Headers() h:any){ const userId=this.userId(h); return (await this.db.query('SELECT count(*)::int count FROM notifications WHERE user_id=$1 AND read_at IS NULL',[userId])).rows[0]; }
  @Patch('notifications/:id/read') async readNotification(@Headers() h:any,@Param('id') id:string){ const userId=this.userId(h); const r=await this.db.query('UPDATE notifications SET read_at=now() WHERE id=$1 AND user_id=$2 RETURNING id,read_at',[id,userId]); if(!r.rowCount) throw new NotFoundException('الإشعار غير موجود'); return r.rows[0]; }
  @Patch('notifications/read-all') async readAllNotifications(@Headers() h:any){ const userId=this.userId(h); const r=await this.db.query('UPDATE notifications SET read_at=now() WHERE user_id=$1 AND read_at IS NULL',[userId]); return {success:true,count:r.rowCount}; }

  @Get('health') health(){ return {service:'jayek-api',status:'ok',version:API_VERSION,brand:BRAND,timestamp:new Date().toISOString()}; }
  @Get('integrations/status') async integrationStatus(@Headers() h:any){ await this.actor(h,['ADMIN','SUPER_ADMIN']); return this.integrations.status(); }
  @Get('health/ready') async ready(){ await this.db.query('SELECT 1'); return {status:'ready',database:'ok',timestamp:new Date().toISOString()}; }
  @Get('health/metrics') async healthMetrics(@Headers() h:any){ await this.actor(h,['ADMIN','SUPER_ADMIN']); const r=await this.db.query(`SELECT (SELECT count(*) FROM orders WHERE status NOT IN ('DELIVERED','CANCELLED','REJECTED','PAYMENT_FAILED'))::int active_orders,(SELECT count(*) FROM riders WHERE is_online=true)::int online_riders,(SELECT count(*) FROM support_tickets WHERE status NOT IN ('RESOLVED','CLOSED'))::int open_support,(SELECT count(*) FROM products WHERE stock_quantity <= low_stock_threshold AND is_available=true)::int low_stock`); return {status:'ok',version:API_VERSION,...r.rows[0],timestamp:new Date().toISOString()}; }
  @Get('config') config(){ return {brand:BRAND,locale:'ar-EG',rtl:true,services:SERVICES,defaultVillage:'الديسمي',paymentMode:'CASH_ON_DELIVERY',paymentMethods:['CASH']}; }

  @Post('auth/request-otp') async requestOtp(@Body() b:any){
    const phone=String(b?.phone||'').trim();
    if(!/^01[0125][0-9]{8}$/.test(phone)) throw new BadRequestException('رقم الهاتف غير صحيح');
    const now=Date.now(), current=this.otpAttempts.get(phone);
    if(!current || now-current.start>=15*60*1000) this.otpAttempts.set(phone,{start:now,count:1});
    else { current.count++; if(current.count>5) throw new BadRequestException('تم تجاوز حد طلبات رمز التحقق، حاول لاحقًا'); }
    const challengeId=randomUUID(), code=this.integrations.generateOtp();
    const codeHash=createHash('sha256').update(code).digest('hex');
    await this.db.query("INSERT INTO otp_challenges(id,phone,code,expires_at) VALUES($1,$2,$3,now()+interval '2 minutes')",[challengeId,phone,codeHash]);
    const sent=await this.integrations.otp.sendOtp(phone,code);
    return {success:true,challengeId,expiresIn:120,provider:sent.provider,devCode:process.env.NODE_ENV==='production'?undefined:code};
  }
  @Post('auth/verify-otp') async verifyOtp(@Body() b:any){
    const r=await this.db.query('SELECT * FROM otp_challenges WHERE id=$1 AND phone=$2 AND expires_at>now() AND consumed_at IS NULL',[b?.challengeId,b?.phone]);
    if(!r.rowCount) throw new UnauthorizedException('رمز التحقق غير صالح أو منتهي');
    const challenge=r.rows[0];
    if(Number(challenge.attempts||0)>=5) throw new UnauthorizedException('تم تجاوز محاولات رمز التحقق');
    await this.db.query('UPDATE otp_challenges SET attempts=attempts+1 WHERE id=$1',[b.challengeId]);
    const submittedHash=createHash('sha256').update(String(b?.code||'')).digest('hex');
    const storedHash=Buffer.from(String(challenge.code),'utf8');
    const submitted=Buffer.from(submittedHash,'utf8');
    if(storedHash.length!==submitted.length || !require('crypto').timingSafeEqual(storedHash,submitted)) throw new UnauthorizedException('رمز التحقق غير صحيح');
    await this.db.query('UPDATE otp_challenges SET consumed_at=now() WHERE id=$1',[b.challengeId]);
    let u=(await this.db.query('SELECT * FROM users WHERE phone=$1',[b.phone])).rows[0];
    if(!u) u=(await this.db.query('INSERT INTO users(phone,name,role) VALUES($1,$2,\'CUSTOMER\') RETURNING *',[b.phone,b.name||null])).rows[0];
    const accessToken=signToken({sub:u.id,role:u.role});
    const refreshToken=randomUUID()+'.'+randomUUID();
    await this.db.query(`INSERT INTO refresh_tokens(id,user_id,token_hash,expires_at) VALUES($1,$2,$3,now()+($4 * interval '1 day'))`,[randomUUID(),u.id,hashToken(refreshToken),REFRESH_TOKEN_TTL_DAYS]);
    await this.db.query(`INSERT INTO audit_logs(user_id,action,entity_type,entity_id,metadata_json) VALUES($1,'AUTH_LOGIN','USER',$1,$2)`,[u.id,JSON.stringify({phone:b.phone})]);
    return {accessToken,refreshToken,tokenType:'Bearer',expiresIn:Number(process.env.ACCESS_TOKEN_TTL_SECONDS||3600),refreshExpiresIn:REFRESH_TOKEN_TTL_DAYS*86400,user:u};
  }
  private userId(headers:any){ const auth=headers['authorization']||''; if(auth.startsWith('Bearer ')){ const p=verifyToken(auth.slice(7)); if(p?.sub)return p.sub; } const id=process.env.ALLOW_DEV_HEADERS==='true'?headers['x-user-id']:undefined; if(!id) throw new UnauthorizedException('جلسة غير صالحة'); return id; }
  private actorId(headers:any){ const auth=headers['authorization']||''; if(auth.startsWith('Bearer ')){ const p=verifyToken(auth.slice(7)); if(p?.sub)return p.sub; } return process.env.ALLOW_DEV_HEADERS==='true' ? (headers['x-user-id']||null) : null; }
  @Post('auth/refresh') async refresh(@Body() b:any){
    if(!b?.refreshToken) throw new UnauthorizedException('Refresh token مطلوب');
    const hash=hashToken(String(b.refreshToken));
    return this.db.tx(async c=>{
      const row=(await c.query(`SELECT rt.*,u.role,u.is_active FROM refresh_tokens rt JOIN users u ON u.id=rt.user_id WHERE rt.token_hash=$1 AND rt.revoked_at IS NULL AND rt.expires_at>now() FOR UPDATE OF rt`,[hash])).rows[0];
      if(!row || !row.is_active) throw new UnauthorizedException('جلسة التحديث غير صالحة');
      await c.query('UPDATE refresh_tokens SET revoked_at=now() WHERE id=$1 AND revoked_at IS NULL',[row.id]);
      const accessToken=signToken({sub:row.user_id,role:row.role});
      const next=randomUUID()+'.'+randomUUID();
      await c.query(`INSERT INTO refresh_tokens(id,user_id,token_hash,expires_at) VALUES($1,$2,$3,now()+($4 * interval '1 day'))`,[randomUUID(),row.user_id,hashToken(next),REFRESH_TOKEN_TTL_DAYS]);
      await c.query(`INSERT INTO audit_logs(user_id,action,entity_type,entity_id) VALUES($1,'AUTH_REFRESH','USER',$1)`,[row.user_id]);
      return {accessToken,refreshToken:next,tokenType:'Bearer',expiresIn:Number(process.env.ACCESS_TOKEN_TTL_SECONDS||3600),refreshExpiresIn:REFRESH_TOKEN_TTL_DAYS*86400};
    });
  }
  @Post('auth/logout') async logout(@Headers() h:any,@Body() b:any){
    const userId=this.userId(h);
    if(b?.refreshToken) await this.db.query('UPDATE refresh_tokens SET revoked_at=now() WHERE user_id=$1 AND token_hash=$2',[userId,hashToken(String(b.refreshToken))]);
    else await this.db.query('UPDATE refresh_tokens SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL',[userId]);
    await this.db.query(`INSERT INTO audit_logs(user_id,action,entity_type,entity_id) VALUES($1,'AUTH_LOGOUT','USER',$1)`,[userId]);
    return {success:true};
  }

  private async notifyUser(userId:string,type:string,title:string,body:string,data:any={},eventKey?:string){
    const key=eventKey || `${type}:${data?.orderId||''}:${userId}`;
    const inserted=await this.db.query(`INSERT INTO notifications(user_id,type,title,body,data_json,event_key) VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT DO NOTHING RETURNING id`,[userId,type,title,body,JSON.stringify(data),key]);
    if(!inserted.rowCount) return {created:false};
    const tokens=(await this.db.query(`SELECT token FROM device_tokens WHERE user_id=$1`,[userId])).rows;
    for(const row of tokens){ try{ await this.integrations.push.send({token:row.token,title,body,data:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,String(v)]))}); }catch{} }
    return {created:true};
  }
  private async notifyOrderStatus(orderId:string,status:string){
    const o=(await this.db.query(`SELECT user_id FROM orders WHERE id=$1`,[orderId])).rows[0];
    const copy=NOTIFICATION_COPY[status]; if(o && copy) await this.notifyUser(o.user_id,'ORDER_STATUS',copy[0],copy[1],{orderId,status},`ORDER_STATUS:${orderId}:${status}`);
  }

  private async actor(headers:any,roles:string[]){ const id=this.userId(headers); const r=await this.db.query('SELECT id,role,is_active FROM users WHERE id=$1',[id]); if(!r.rowCount||!r.rows[0].is_active||!roles.includes(r.rows[0].role)) throw new UnauthorizedException('غير مصرح'); return r.rows[0]; }
  private async merchantActor(headers:any,merchantId:string){ const actor=await this.actor(headers,['MERCHANT','ADMIN','SUPER_ADMIN']); if(['ADMIN','SUPER_ADMIN'].includes(actor.role)) return actor; const owned=await this.db.query('SELECT 1 FROM merchants WHERE id=$1 AND owner_user_id=$2 AND is_active=true',[merchantId,actor.id]); if(!owned.rowCount) throw new ForbiddenException('غير مصرح لهذا المتجر'); return actor; }

  @Get('locations/villages') async villages(){ return (await this.db.query('SELECT id,name,center_latitude,center_longitude FROM villages WHERE is_active=true ORDER BY name')).rows; }
  @Get('delivery-zones') async deliveryZones(){ return (await this.db.query('SELECT id,name,center_latitude,center_longitude,radius_km,base_fee,per_km_fee,min_fee FROM delivery_zones WHERE is_active=true ORDER BY name')).rows; }
  @Get('addresses') async addresses(@Headers() h:any){ return (await this.db.query('SELECT * FROM addresses WHERE user_id=$1 ORDER BY created_at DESC',[this.userId(h)])).rows; }
  @Post('addresses') async addAddress(@Headers() h:any,@Body() b:any){
    if(!b?.village||b.latitude==null||b.longitude==null) throw new BadRequestException('العنوان والموقع مطلوبان');
    if(!validLatLon(b.latitude,b.longitude)) throw new BadRequestException('إحداثيات الموقع غير صالحة');
    if(String(b.village).trim().length>120||String(b.details||'').length>1000||String(b.label||'').length>50) throw new BadRequestException('بيانات العنوان طويلة جدًا');
    const r=await this.db.query('INSERT INTO addresses(user_id,label,village,details,latitude,longitude,is_default) VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING *',[this.userId(h),b.label||'البيت',b.village,b.details||null,b.latitude,b.longitude,!!b.isDefault]);
    if(b.isDefault) await this.db.query('UPDATE addresses SET is_default=false WHERE user_id=$1 AND id<>$2',[this.userId(h),r.rows[0].id]);
    return r.rows[0];
  }

  @Get('categories') async categories(){ return (await this.db.query('SELECT * FROM categories WHERE is_active=true ORDER BY sort_order,name')).rows; }
  @Get('home') async home(@Query('village') village='الديسمي'){
    const [cats,merchants,popular]=await Promise.all([
      this.db.query('SELECT * FROM categories WHERE is_active=true ORDER BY sort_order,name'),
      this.db.query(`SELECT m.*,COUNT(p.id)::int AS product_count FROM merchants m LEFT JOIN products p ON p.merchant_id=m.id AND p.is_available=true WHERE m.is_active=true AND m.village=$1 GROUP BY m.id ORDER BY m.rating DESC,m.name`,[village]),
      this.db.query(`SELECT p.id,p.name,p.price,p.image_url,p.merchant_id,m.name AS merchant_name FROM products p JOIN merchants m ON m.id=p.merchant_id WHERE p.is_available=true AND m.is_active=true AND m.village=$1 ORDER BY p.order_count DESC,p.created_at DESC LIMIT 8`,[village])
    ]);
    return {village,banners:[{title:'محلات بلدك أقرب مما تتخيل',subtitle:'اطلب اللي محتاجه وجايك لحد بابك',cta:'اطلب الآن'}],categories:cats.rows,merchants:merchants.rows,popular:popular.rows};
  }
  @Get('search') async search(@Query('q') q='',@Query('village') village='الديسمي'){
    if(!q.trim()) return {merchants:[],products:[]}; const like=`%${q.trim()}%`;
    const [m,p]=await Promise.all([
      this.db.query('SELECT * FROM merchants WHERE is_active=true AND village=$1 AND name ILIKE $2 ORDER BY rating DESC LIMIT 20',[village,like]),
      this.db.query('SELECT p.*,m.name merchant_name FROM products p JOIN merchants m ON m.id=p.merchant_id WHERE p.is_available=true AND m.village=$1 AND (p.name ILIKE $2 OR COALESCE(p.description,\'\') ILIKE $2) ORDER BY p.order_count DESC LIMIT 30',[village,like])
    ]); return {merchants:m.rows,products:p.rows};
  }
  @Get('merchants') async merchants(@Query('village') village='الديسمي',@Query('type') type?:string){ const p=[village]; let sql='SELECT * FROM merchants WHERE is_active=true AND village=$1'; if(type){p.push(type);sql+=' AND type=$2';} sql+=' ORDER BY rating DESC,name'; return (await this.db.query(sql,p)).rows; }
  @Get('merchants/:id') async merchant(@Param('id') id:string){ const m=(await this.db.query('SELECT * FROM merchants WHERE id=$1 AND is_active=true',[id])).rows[0]; if(!m) throw new NotFoundException('المتجر غير موجود'); const products=(await this.db.query(`SELECT p.*,c.name category_name FROM products p LEFT JOIN categories c ON c.id=p.category_id WHERE p.merchant_id=$1 AND p.is_available=true ORDER BY c.sort_order,c.name,p.name`,[id])).rows; return {...m,products}; }
  @Get('products/:id') async product(@Param('id') id:string){ const r=await this.db.query('SELECT p.*,m.name merchant_name,m.delivery_fee,m.delivery_minutes FROM products p JOIN merchants m ON m.id=p.merchant_id WHERE p.id=$1 AND p.is_available=true',[id]); if(!r.rowCount) throw new NotFoundException('المنتج غير متاح'); return r.rows[0]; }

  private async reserveOrderStock(c:any, orderId:string, items:any[]){
    for(const x of items){
      const q=await c.query(`UPDATE products SET stock_quantity=stock_quantity-$1, stock_reserved=stock_reserved+$1, order_count=order_count+1 WHERE id=$2 AND stock_quantity >= $1 RETURNING id`,[x.qty,x.p.id]);
      if(!q.rowCount) throw new BadRequestException(`المخزون غير كافٍ للمنتج: ${x.p.name}`);
      await c.query(`INSERT INTO order_stock_reservations(order_id,product_id,quantity,status) VALUES($1,$2,$3,'RESERVED')`,[orderId,x.p.id,x.qty]);
    }
  }
  private async releaseOrderStock(c:any, orderId:string, finalize:boolean){
    const rows=(await c.query(`SELECT product_id,quantity FROM order_stock_reservations WHERE order_id=$1 AND status='RESERVED' FOR UPDATE`,[orderId])).rows;
    for(const row of rows){
      if(finalize) await c.query(`UPDATE products SET stock_reserved=GREATEST(0,stock_reserved-$1) WHERE id=$2`,[row.quantity,row.product_id]);
      else await c.query(`UPDATE products SET stock_quantity=stock_quantity+$1, stock_reserved=GREATEST(0,stock_reserved-$1) WHERE id=$2`,[row.quantity,row.product_id]);
      await c.query(`UPDATE order_stock_reservations SET status=$1,released_at=now() WHERE order_id=$2 AND id=$3 AND status='RESERVED'`,[finalize?'COMMITTED':'RELEASED',orderId,row.id]);
    }
  }

  @Post('orders') async createOrder(@Headers() h:any,@Body() b:any){
    const userId=this.userId(h); const key=h['idempotency-key']; if(!key) throw new BadRequestException('Idempotency-Key مطلوب');
    const existing=await this.db.query('SELECT id,user_id FROM orders WHERE idempotency_key=$1',[key]); if(existing.rowCount){ if(String(existing.rows[0].user_id)!==String(userId)) throw new ConflictException('Idempotency-Key مستخدم بالفعل'); return this.orderById(existing.rows[0].id); }
    if(!b?.merchantId||!validUuid(String(b.merchantId))||!Array.isArray(b.items)||!b.items.length||b.items.length>50) throw new BadRequestException('السلة غير صالحة');
    const result=await this.db.tx(async c=>{
      const merchant=(await c.query('SELECT * FROM merchants WHERE id=$1 AND is_active=true FOR SHARE',[b.merchantId])).rows[0]; if(!merchant) throw new BadRequestException('المتجر غير متاح');
      const ids=b.items.map((x:any)=>x.productId); if(ids.some((id:any)=>!validUuid(id))||ids.length!==new Set(ids).size) throw new BadRequestException('السلة غير صالحة'); const ps=(await c.query('SELECT * FROM products WHERE id=ANY($1::uuid[]) AND merchant_id=$2 AND is_available=true FOR UPDATE',[ids,b.merchantId])).rows; const map=new Map(ps.map((p:any)=>[p.id,p]));
      if(ps.length!==new Set(ids).size) throw new BadRequestException('يوجد منتج غير متاح');
      let subtotal=0; const items=[]; for(const i of b.items){const p:any=map.get(i.productId); const qty=Math.floor(Number(i.quantity||1)); if(!Number.isFinite(qty)||qty<1||qty>100) throw new BadRequestException('كمية المنتج غير صالحة'); subtotal+=Number(p.price)*qty; if(subtotal>1000000) throw new BadRequestException('قيمة الطلب كبيرة جدًا'); items.push({p,qty});}
      let discount=0;
      let coupon:any=null;
      if(b.couponCode){
        coupon=(await c.query(`SELECT * FROM coupons WHERE UPPER(code)=UPPER($1) AND is_active=true AND starts_at<=now() AND (expires_at IS NULL OR expires_at>now()) FOR UPDATE`,[String(b.couponCode).trim()])).rows[0];
        if(!coupon) throw new BadRequestException('الكوبون غير صالح أو منتهي');
        if(Number(subtotal)<Number(coupon.min_subtotal)) throw new BadRequestException(`الحد الأدنى للطلب ${coupon.min_subtotal} جنيه`);
        if(coupon.usage_limit!=null && Number(coupon.usage_count)>=Number(coupon.usage_limit)) throw new BadRequestException('الكوبون استنفد الحد الأقصى للاستخدام');
        const used=(await c.query('SELECT count(*)::int count FROM coupon_redemptions WHERE coupon_id=$1 AND user_id=$2',[coupon.id,userId])).rows[0].count;
        if(Number(used)>=Number(coupon.per_user_limit)) throw new BadRequestException('تم استخدام الكوبون من قبل');
        discount=coupon.discount_type==='PERCENT' ? subtotal*(Number(coupon.discount_value)/100) : Number(coupon.discount_value);
        if(coupon.max_discount!=null) discount=Math.min(discount,Number(coupon.max_discount));
        discount=Math.min(Math.max(0,discount),subtotal);
      }
      if(b.addressId && !validUuid(String(b.addressId))) throw new BadRequestException('العنوان غير صالح');
      const address=b.addressId ? (await c.query('SELECT * FROM addresses WHERE id=$1 AND user_id=$2 FOR SHARE',[b.addressId,userId])).rows[0] : null;
      if(b.addressId && !address) throw new BadRequestException('العنوان غير صالح');
      if(!address || !validLatLon(address.latitude,address.longitude)) throw new BadRequestException('العنوان يحتاج موقعًا جغرافيًا صحيحًا');
      const zones=(await c.query('SELECT * FROM delivery_zones WHERE is_active=true')).rows;
      const zone=zones.map((z:any)=>({...z,distanceKm:distanceKm(Number(address.latitude),Number(address.longitude),Number(z.center_latitude),Number(z.center_longitude))}))
        .filter((z:any)=>z.distanceKm<=Number(z.radius_km)).sort((a:any,b:any)=>a.distanceKm-b.distanceKm)[0];
      if(!zone) throw new BadRequestException('العنوان خارج نطاق التوصيل');
      const roundedDeliveryFee=deliveryFee(Number(zone.distanceKm),Number(zone.base_fee),Number(zone.per_km_fee),Number(zone.min_fee)); discount=Number(discount.toFixed(2)); const total=subtotal+roundedDeliveryFee-discount;
      const order=(await c.query(`INSERT INTO orders(user_id,merchant_id,address_id,status,subtotal,delivery_fee,discount,total,idempotency_key,notes) VALUES($1,$2,$3,'CREATED',$4,$5,$6,$7,$8,$9) RETURNING *`,[userId,b.merchantId,b.addressId||null,subtotal,roundedDeliveryFee,discount,total,key,b.notes||null])).rows[0];
      for(const x of items) await c.query('INSERT INTO order_items(order_id,product_id,name_snapshot,unit_price,quantity,options_json) VALUES($1,$2,$3,$4,$5,$6)',[order.id,x.p.id,x.p.name,x.p.price,x.qty,JSON.stringify({})]);
      await this.reserveOrderStock(c,order.id,items);
      await c.query('INSERT INTO order_status_history(order_id,status,actor_type) VALUES($1,\'CREATED\',\'CUSTOMER\')',[order.id]);
      await c.query(`INSERT INTO payments(order_id,user_id,method,status,amount,currency,provider) VALUES($1,$2,'CASH','PENDING',$3,'EGP','cod') ON CONFLICT DO NOTHING`,[order.id,userId,total]);
      if(coupon){ await c.query('INSERT INTO coupon_redemptions(coupon_id,user_id,order_id,discount_amount) VALUES($1,$2,$3,$4)',[coupon.id,userId,order.id,discount]); await c.query('UPDATE coupons SET usage_count=usage_count+1 WHERE id=$1',[coupon.id]); }
      return {...order,items:items.map(x=>({product_id:x.p.id,name:x.p.name,unit_price:x.p.price,quantity:x.qty}))};
    });
    await this.notifyOrderStatus(result.id,'CREATED');
    return result;
  }
  async orderById(id:string){ const o=(await this.db.query(`SELECT o.*,m.name merchant_name,m.delivery_minutes,(SELECT p.method FROM payments p WHERE p.order_id=o.id ORDER BY p.created_at DESC LIMIT 1) payment_method,(SELECT p.status FROM payments p WHERE p.order_id=o.id ORDER BY p.created_at DESC LIMIT 1) payment_status FROM orders o JOIN merchants m ON m.id=o.merchant_id WHERE o.id=$1`,[id])).rows[0]; if(!o) throw new NotFoundException('الطلب غير موجود'); const items=(await this.db.query('SELECT * FROM order_items WHERE order_id=$1 ORDER BY id',[id])).rows; const history=(await this.db.query('SELECT * FROM order_status_history WHERE order_id=$1 ORDER BY created_at',[id])).rows; return {...o,items,history}; }
  @Get('coupons/validate') async validateCoupon(@Headers() h:any,@Query('code') code:string,@Query('subtotal') subtotalRaw:string){
    const userId=this.userId(h); const subtotal=Number(subtotalRaw||0); if(!code||!Number.isFinite(subtotal)||subtotal<0) throw new BadRequestException('بيانات الكوبون غير صالحة');
    const c=(await this.db.query(`SELECT * FROM coupons WHERE UPPER(code)=UPPER($1) AND is_active=true AND starts_at<=now() AND (expires_at IS NULL OR expires_at>now())`,[code.trim()])).rows[0];
    if(!c) throw new BadRequestException('الكوبون غير صالح أو منتهي');
    if(subtotal<Number(c.min_subtotal)) throw new BadRequestException(`الحد الأدنى ${c.min_subtotal} جنيه`);
    if(c.usage_limit!=null && Number(c.usage_count)>=Number(c.usage_limit)) throw new BadRequestException('الكوبون استنفد');
    const used=(await this.db.query('SELECT count(*)::int count FROM coupon_redemptions WHERE coupon_id=$1 AND user_id=$2',[c.id,userId])).rows[0].count;
    if(Number(used)>=Number(c.per_user_limit)) throw new BadRequestException('تم استخدام الكوبون من قبل');
    let discount=c.discount_type==='PERCENT'?subtotal*Number(c.discount_value)/100:Number(c.discount_value); if(c.max_discount!=null) discount=Math.min(discount,Number(c.max_discount)); discount=Math.min(discount,subtotal);
    return {valid:true,code:c.code,discount:Number(discount.toFixed(2)),discountType:c.discount_type};
  }
  @Get('favorites') async favorites(@Headers() h:any){ return (await this.db.query(`SELECT m.* FROM favorites f JOIN merchants m ON m.id=f.merchant_id WHERE f.user_id=$1 ORDER BY f.created_at DESC`,[this.userId(h)])).rows; }
  @Post('favorites/:merchantId') async addFavorite(@Headers() h:any,@Param('merchantId') merchantId:string){ const userId=this.userId(h); const m=(await this.db.query('SELECT id FROM merchants WHERE id=$1 AND is_active=true',[merchantId])).rows[0]; if(!m) throw new NotFoundException('المتجر غير موجود'); await this.db.query('INSERT INTO favorites(user_id,merchant_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[userId,merchantId]); return {success:true}; }
  @Delete('favorites/:merchantId') async removeFavorite(@Headers() h:any,@Param('merchantId') merchantId:string){ await this.db.query('DELETE FROM favorites WHERE user_id=$1 AND merchant_id=$2',[this.userId(h),merchantId]); return {success:true}; }
  @Get('orders/:id/review') async orderReview(@Headers() h:any,@Param('id') id:string){ return (await this.db.query('SELECT r.* FROM reviews r JOIN orders o ON o.id=r.order_id WHERE r.order_id=$1 AND o.user_id=$2',[id,this.userId(h)])).rows[0]||null; }
  @Post('orders/:id/reorder') async reorder(@Headers() h:any,@Param('id') id:string){ const userId=this.userId(h); const o=(await this.db.query('SELECT merchant_id,address_id,notes FROM orders WHERE id=$1 AND user_id=$2',[id,userId])).rows[0]; if(!o) throw new NotFoundException('الطلب غير موجود'); const items=(await this.db.query('SELECT oi.product_id,oi.quantity,p.name,p.price,p.image_url,p.merchant_id FROM order_items oi JOIN products p ON p.id=oi.product_id WHERE oi.order_id=$1',[id])).rows; return {merchantId:o.merchant_id,addressId:o.address_id,notes:o.notes,items}; }
  @Get('orders/:id') async order(@Param('id') id:string,@Headers() h:any){ const userId=this.userId(h); const access=await this.db.query('SELECT 1 FROM orders WHERE id=$1 AND user_id=$2',[id,userId]); if(!access.rowCount) throw new NotFoundException('الطلب غير موجود'); return this.orderById(id); }
  @Get('orders') async orders(@Headers() h:any){return (await this.db.query('SELECT o.*,m.name merchant_name FROM orders o JOIN merchants m ON m.id=o.merchant_id WHERE o.user_id=$1 ORDER BY o.created_at DESC',[this.userId(h)])).rows;}
  @Post('orders/:id/status') async status(@Param('id') id:string,@Headers() h:any,@Body() b:any){
    const next=b?.status; const userId=this.userId(h);
    if(next!=='CANCELLED') throw new BadRequestException('العميل يمكنه الإلغاء فقط');
    return this.db.tx(async c=>{
      const o=(await c.query('SELECT * FROM orders WHERE id=$1 AND user_id=$2 FOR UPDATE',[id,userId])).rows[0];
      if(!o) throw new NotFoundException('الطلب غير موجود');
      if(!TRANSITIONS[o.status]?.includes(next)) throw new BadRequestException(`invalid transition ${o.status} -> ${next}`);
      await c.query('UPDATE orders SET status=$1,updated_at=now() WHERE id=$2',[next,id]);
      await this.releaseOrderStock(c,id,false);
      await c.query('INSERT INTO order_status_history(order_id,status,actor_type,actor_id) VALUES($1,$2,$3,$4)',[id,next,'CUSTOMER',userId]);
      return {success:true,orderId:id,status:next};
    });
  }
  @Get('merchant/orders/:merchantId') async merchantOrders(@Param('merchantId') merchantId:string,@Headers() h:any,@Query('status') status?:string){ await this.merchantActor(h,merchantId); const p=[merchantId];let sql='SELECT o.*,u.name customer_name,u.phone customer_phone FROM orders o JOIN users u ON u.id=o.user_id WHERE o.merchant_id=$1';if(status){p.push(status);sql+=' AND o.status=$2';}sql+=' ORDER BY o.created_at DESC';return (await this.db.query(sql,p)).rows; }
  @Get('rider/tasks') async riderTasks(@Headers() h:any){ await this.actor(h,['RIDER','ADMIN','SUPER_ADMIN']); return (await this.db.query(`SELECT o.*,m.name merchant_name,m.village FROM orders o JOIN merchants m ON m.id=o.merchant_id WHERE o.status IN ('READY_FOR_PICKUP','ASSIGNED_RIDER') ORDER BY o.created_at`)).rows; }

  @Get('merchant/dashboard/:merchantId') async merchantDashboard(@Param('merchantId') merchantId:string,@Headers() h:any){
    await this.merchantActor(h,merchantId);
    const [orders,products,stats]=await Promise.all([
      this.db.query(`SELECT o.id,o.status,o.total,o.created_at,u.name customer_name,u.phone customer_phone FROM orders o JOIN users u ON u.id=o.user_id WHERE o.merchant_id=$1 ORDER BY o.created_at DESC LIMIT 50`,[merchantId]),
      this.db.query(`SELECT id,name,price,is_available,order_count FROM products WHERE merchant_id=$1 ORDER BY name`,[merchantId]),
      this.db.query(`SELECT count(*)::int orders, count(*) FILTER(WHERE status='DELIVERED')::int delivered, count(*) FILTER(WHERE status IN ('CREATED','CONFIRMED','ACCEPTED_BY_MERCHANT','PREPARING','READY_FOR_PICKUP'))::int active, COALESCE(sum(total) FILTER(WHERE status='DELIVERED'),0) revenue FROM orders WHERE merchant_id=$1`,[merchantId])
    ]);
    return {merchantId,stats:stats.rows[0],orders:orders.rows,products:products.rows};
  }
  @Get('merchant/orders/:merchantId/:orderId') async merchantOrder(@Param('merchantId') merchantId:string,@Param('orderId') orderId:string,@Headers() h:any){
    await this.merchantActor(h,merchantId);
    const o=(await this.db.query(`SELECT o.*,u.name customer_name,u.phone customer_phone,a.village,a.details address_details FROM orders o JOIN users u ON u.id=o.user_id LEFT JOIN addresses a ON a.id=o.address_id WHERE o.id=$1 AND o.merchant_id=$2`,[orderId,merchantId])).rows[0];
    if(!o) throw new NotFoundException('الطلب غير موجود');
    const items=(await this.db.query('SELECT * FROM order_items WHERE order_id=$1 ORDER BY id',[orderId])).rows;
    return {...o,items};
  }
  @Patch('merchant/orders/:merchantId/:orderId/status') async merchantStatus(@Param('merchantId') merchantId:string,@Param('orderId') orderId:string,@Headers() h:any,@Body() b:any){
    await this.merchantActor(h,merchantId);
    if(!['ACCEPTED_BY_MERCHANT','PREPARING','READY_FOR_PICKUP','REJECTED'].includes(b?.status)) throw new BadRequestException('حالة غير مسموحة للتاجر');
    const result=await this.db.tx(async c=>{
      const o=(await c.query('SELECT * FROM orders WHERE id=$1 AND merchant_id=$2 FOR UPDATE',[orderId,merchantId])).rows[0];
      if(!o) throw new NotFoundException('الطلب غير موجود');
      if(!TRANSITIONS[o.status]?.includes(b.status)) throw new BadRequestException(`invalid transition ${o.status} -> ${b.status}`);
      await c.query('UPDATE orders SET status=$1,updated_at=now() WHERE id=$2',[b.status,orderId]);
      if(b.status==='REJECTED') await this.releaseOrderStock(c,orderId,false);
      await c.query('INSERT INTO order_status_history(order_id,status,actor_type,actor_id) VALUES($1,$2,\'MERCHANT\',$3)',[orderId,b.status,this.actorId(h)]);
      return {orderId,status:b.status};
    });
    await this.notifyOrderStatus(result.orderId,result.status);
    return this.orderById(result.orderId);
  }
  @Post('merchant/products') async addProduct(@Headers() h:any,@Body() b:any){
    await this.actor(h,['MERCHANT','ADMIN','SUPER_ADMIN']);
    if(!b?.merchantId||!b?.name||b.price==null) throw new BadRequestException('بيانات المنتج ناقصة');
    const price=Number(b.price); if(!Number.isFinite(price)||price<=0||price>1000000) throw new BadRequestException('سعر المنتج غير صالح');
    if(String(b.name).trim().length>180||String(b.description||'').length>5000||String(b.imageUrl||'').length>2000) throw new BadRequestException('بيانات المنتج طويلة جدًا');
    await this.merchantActor(h,String(b.merchantId));
    return (await this.db.query(`INSERT INTO products(merchant_id,category_id,name,description,price,image_url,is_available) VALUES($1,$2,$3,$4,$5,$6,COALESCE($7,true)) RETURNING *`,[b.merchantId,b.categoryId||null,String(b.name).trim(),b.description||null,price,b.imageUrl||null,b.isAvailable])).rows[0];
  }
  @Get('merchant/inventory/:merchantId') async merchantInventory(@Param('merchantId') merchantId:string,@Headers() h:any){
    await this.merchantActor(h,merchantId);
    const rows=(await this.db.query(`SELECT id,name,price,is_available,stock_quantity,low_stock_threshold,order_count,
      (stock_quantity <= low_stock_threshold) AS low_stock FROM products WHERE merchant_id=$1 ORDER BY low_stock DESC,name`,[merchantId])).rows;
    return {merchantId,items:rows,lowStockCount:rows.filter((x:any)=>x.low_stock).length};
  }
  @Patch('merchant/inventory/:productId') async updateInventory(@Param('productId') productId:string,@Headers() h:any,@Body() b:any){
    const productOwner=(await this.db.query('SELECT merchant_id FROM products WHERE id=$1',[productId])).rows[0];
    if(!productOwner) throw new NotFoundException('المنتج غير موجود');
    await this.merchantActor(h,String(productOwner.merchant_id));
    if(b?.stockQuantity==null || !Number.isInteger(Number(b.stockQuantity)) || Number(b.stockQuantity)<0 || Number(b.stockQuantity)>100000000) throw new BadRequestException('stockQuantity غير صالح');
    const threshold=b.lowStockThreshold==null?undefined:Number(b.lowStockThreshold);
    if(threshold!==undefined && (!Number.isInteger(threshold)||threshold<0||threshold>100000000)) throw new BadRequestException('lowStockThreshold غير صالح');
    const fields=['stock_quantity=$1']; const values:any[]=[Math.floor(Number(b.stockQuantity))];
    if(threshold!==undefined){fields.push('low_stock_threshold=$2');values.push(Math.floor(threshold));}
    values.push(productId);
    const r=await this.db.query(`UPDATE products SET ${fields.join(',')} WHERE id=$${values.length} RETURNING *`,values);
    if(!r.rowCount) throw new NotFoundException('المنتج غير موجود'); return r.rows[0];
  }
  @Get('merchant/alerts/:merchantId') async merchantAlerts(@Param('merchantId') merchantId:string,@Headers() h:any){
    await this.merchantActor(h,merchantId);
    const [stock,orders]=await Promise.all([
      this.db.query(`SELECT id,name,stock_quantity,low_stock_threshold FROM products WHERE merchant_id=$1 AND is_available=true AND stock_quantity <= low_stock_threshold ORDER BY stock_quantity,name`,[merchantId]),
      this.db.query(`SELECT o.id,o.status,o.created_at,u.name customer_name FROM orders o JOIN users u ON u.id=o.user_id WHERE o.merchant_id=$1 AND o.status IN ('CREATED','CONFIRMED') ORDER BY o.created_at ASC`,[merchantId])
    ]);
    return {lowStock:stock.rows,pendingOrders:orders.rows};
  }

  @Patch('merchant/products/:id') async updateProduct(@Param('id') id:string,@Headers() h:any,@Body() b:any){
    await this.actor(h,['MERCHANT','ADMIN','SUPER_ADMIN']);
    if(b.price!==undefined){const price=Number(b.price); if(!Number.isFinite(price)||price<=0||price>1000000) throw new BadRequestException('سعر المنتج غير صالح');}
    if(b.name!==undefined && String(b.name).trim().length>180) throw new BadRequestException('اسم المنتج طويل جدًا');
    if(b.description!==undefined && String(b.description).length>5000) throw new BadRequestException('وصف المنتج طويل جدًا');
    const fields:any[]=[]; const values:any[]=[];
    for(const [k,col] of Object.entries({name:'name',description:'description',price:'price',imageUrl:'image_url',isAvailable:'is_available'})){if(b[k]!==undefined){values.push(b[k]);fields.push(`${col}=$${values.length}`)}}
    if(!fields.length) throw new BadRequestException('لا توجد تغييرات');
    const product=(await this.db.query('SELECT merchant_id FROM products WHERE id=$1',[id])).rows[0];
    if(!product) throw new NotFoundException('المنتج غير موجود');
    const actorUser=this.userId(h);
    if(h['x-user-id'] && process.env.NODE_ENV==='production') throw new UnauthorizedException('استخدم Bearer Token');
    if((await this.db.query(`SELECT 1 FROM merchants m JOIN users u ON u.id=m.owner_user_id WHERE m.id=$1 AND u.id=$2`,[product.merchant_id,actorUser])).rowCount===0 && !['ADMIN','SUPER_ADMIN'].includes((await this.db.query('SELECT role FROM users WHERE id=$1',[actorUser])).rows[0]?.role)) throw new ForbiddenException('غير مصرح لهذا المتجر');
    values.push(id);
    const r=await this.db.query(`UPDATE products SET ${fields.join(',')} WHERE id=$${values.length} RETURNING *`,values); if(!r.rowCount) throw new NotFoundException('المنتج غير موجود'); return r.rows[0];
  }

  @Post('riders') async createRider(@Headers() h:any,@Body() b:any){
    await this.actor(h,['ADMIN','SUPER_ADMIN']);
    if(!b?.userId) throw new BadRequestException('userId مطلوب');
    return (await this.db.query(`INSERT INTO riders(user_id,vehicle_type) VALUES($1,$2) ON CONFLICT(user_id) DO UPDATE SET vehicle_type=EXCLUDED.vehicle_type RETURNING *`,[b.userId,b.vehicleType||'MOTORCYCLE'])).rows[0];
  }
  @Get('rider/me') async riderMe(@Headers() h:any){ await this.actor(h,['RIDER','ADMIN','SUPER_ADMIN']); return (await this.db.query('SELECT r.*,u.name,u.phone FROM riders r JOIN users u ON u.id=r.user_id WHERE r.user_id=$1',[this.userId(h)])).rows[0]||null; }
  @Patch('rider/online') async riderOnline(@Headers() h:any,@Body() b:any){ await this.actor(h,['RIDER','ADMIN','SUPER_ADMIN']); return (await this.db.query('UPDATE riders SET is_online=$1 WHERE user_id=$2 RETURNING *',[!!b?.online,this.userId(h)])).rows[0]; }
  @Get('rider/tasks/available') async riderAvailable(@Headers() h:any){ await this.actor(h,['RIDER','ADMIN','SUPER_ADMIN']); return (await this.db.query(`SELECT o.id,o.total,o.status,o.created_at,m.name merchant_name,m.village,m.delivery_fee FROM orders o JOIN merchants m ON m.id=o.merchant_id WHERE o.status='READY_FOR_PICKUP' ORDER BY o.created_at ASC LIMIT 30`)).rows; }
  @Get('rider/tasks/active') async riderActive(@Headers() h:any){ await this.actor(h,['RIDER','ADMIN','SUPER_ADMIN']); return (await this.db.query(`SELECT o.id,o.total,o.status,o.created_at,m.name merchant_name,m.village,m.delivery_fee,a.details address_details,a.latitude,a.longitude,d.assigned_at,d.picked_up_at,d.delivered_at,d.proof_url FROM orders o JOIN deliveries d ON d.order_id=o.id JOIN riders r ON r.id=d.rider_id JOIN merchants m ON m.id=o.merchant_id LEFT JOIN addresses a ON a.id=o.address_id WHERE r.user_id=$1 AND o.status IN ('ASSIGNED_RIDER','PICKED_UP','ON_THE_WAY') ORDER BY d.assigned_at DESC`,[this.userId(h)])).rows; }
  @Get('rider/earnings') async riderEarnings(@Headers() h:any,@Query('days') days?:string){ await this.actor(h,['RIDER','ADMIN','SUPER_ADMIN']); const n=Math.min(Math.max(Number(days||30)||30,1),90); const rider=(await this.db.query('SELECT id FROM riders WHERE user_id=$1',[this.userId(h)])).rows[0]; if(!rider) throw new NotFoundException('السائق غير مسجل'); const rows=(await this.db.query(`SELECT count(*)::int deliveries, COALESCE(sum(o.delivery_fee),0)::numeric total_delivery_fees, COALESCE(sum(o.total),0)::numeric gross_order_value FROM deliveries d JOIN orders o ON o.id=d.order_id WHERE d.rider_id=$1 AND o.status='DELIVERED' AND d.delivered_at >= now() - ($2::text || ' days')::interval`,[rider.id,n])).rows[0]; return {days:n,deliveryCount:rows.deliveries,totalDeliveryFees:Number(rows.total_delivery_fees),grossOrderValue:Number(rows.gross_order_value)}; }
  @Post('rider/tasks/:orderId/accept') async riderAccept(@Param('orderId') orderId:string,@Headers() h:any){
    await this.actor(h,['RIDER','ADMIN','SUPER_ADMIN']); const rider=(await this.db.query('SELECT * FROM riders WHERE user_id=$1',[this.userId(h)])).rows[0]; if(!rider) throw new BadRequestException('السائق غير مسجل'); if(!rider.is_online) throw new BadRequestException('يجب أن تكون متصلًا لاستلام الطلبات');
    const result=await this.db.tx(async c=>{const o=(await c.query('SELECT * FROM orders WHERE id=$1 FOR UPDATE',[orderId])).rows[0];if(!o)throw new NotFoundException('الطلب غير موجود');if(o.status!=='READY_FOR_PICKUP')throw new BadRequestException('الطلب لم يعد متاحًا');await c.query('INSERT INTO deliveries(order_id,rider_id,assigned_at) VALUES($1,$2,now()) ON CONFLICT(order_id) DO UPDATE SET rider_id=EXCLUDED.rider_id,assigned_at=now()',[orderId,rider.id]);await c.query('UPDATE orders SET status=\'ASSIGNED_RIDER\',updated_at=now() WHERE id=$1',[orderId]);await c.query('INSERT INTO order_status_history(order_id,status,actor_type,actor_id) VALUES($1,\'ASSIGNED_RIDER\',\'RIDER\',$2)',[orderId,this.userId(h)]);return {orderId,status:'ASSIGNED_RIDER'};}); await this.notifyOrderStatus(result.orderId,result.status); return this.orderById(result.orderId);
  }
  @Patch('rider/location') async riderLocation(@Headers() h:any,@Body() b:any){
    await this.actor(h,['RIDER','ADMIN','SUPER_ADMIN']); if(b?.latitude==null||b?.longitude==null)throw new BadRequestException('الموقع مطلوب');
    if(!validLatLon(b.latitude,b.longitude)) throw new BadRequestException('إحداثيات الموقع غير صالحة');
    if(b.accuracy!=null && (!Number.isFinite(Number(b.accuracy)) || Number(b.accuracy)<0 || Number(b.accuracy)>10000)) throw new BadRequestException('دقة الموقع غير صالحة');
    const rider=(await this.db.query('UPDATE riders SET latitude=$1,longitude=$2,is_online=true,last_location_at=now() WHERE user_id=$3 RETURNING *',[b.latitude,b.longitude,this.userId(h)])).rows[0];
    if(!rider) throw new NotFoundException('السائق غير مسجل');
    const active=(await this.db.query(`SELECT d.order_id FROM deliveries d JOIN orders o ON o.id=d.order_id WHERE d.rider_id=$1 AND o.status IN ('ASSIGNED_RIDER','PICKED_UP','ON_THE_WAY')`,[rider.id])).rows;
    await this.db.query(`INSERT INTO rider_location_events(rider_id,order_id,latitude,longitude,accuracy) SELECT $1,d.order_id,$2,$3,$4 FROM deliveries d WHERE d.rider_id=$1 AND d.order_id IN (SELECT id FROM orders WHERE status IN ('ASSIGNED_RIDER','PICKED_UP','ON_THE_WAY'))`,[rider.id,b.latitude,b.longitude,b.accuracy||null]);
    for(const a of active) realtime.emit('order:location',{orderId:a.order_id,riderId:rider.id,latitude:Number(b.latitude),longitude:Number(b.longitude),accuracy:b.accuracy||null,recordedAt:new Date().toISOString()});
    return rider;
  }
  @Patch('rider/orders/:orderId/status') async riderStatus(@Param('orderId') orderId:string,@Headers() h:any,@Body() b:any){
    await this.actor(h,['RIDER','ADMIN','SUPER_ADMIN']); const allowed=['PICKED_UP','ON_THE_WAY','DELIVERED']; if(!allowed.includes(b?.status))throw new BadRequestException('حالة غير مسموحة للسائق');
    const result=await this.db.tx(async c=>{const o=(await c.query(`SELECT o.* FROM orders o JOIN deliveries d ON d.order_id=o.id JOIN riders r ON r.id=d.rider_id WHERE o.id=$1 AND r.user_id=$2 FOR UPDATE`,[orderId,this.userId(h)])).rows[0];if(!o)throw new NotFoundException('المهمة غير موجودة');if(!TRANSITIONS[o.status]?.includes(b.status))throw new BadRequestException(`invalid transition ${o.status} -> ${b.status}`);await c.query('UPDATE orders SET status=$1,updated_at=now() WHERE id=$2',[b.status,orderId]);if(b.status==='PICKED_UP')await c.query('UPDATE deliveries SET picked_up_at=now() WHERE order_id=$1',[orderId]);if(b.status==='DELIVERED'){await c.query('UPDATE deliveries SET delivered_at=now(),proof_url=COALESCE($2,proof_url) WHERE order_id=$1',[orderId,b.proofUrl||null]);await c.query("UPDATE payments SET status='PAID',updated_at=now() WHERE order_id=$1 AND method='CASH' AND status='PENDING'",[orderId]);await this.releaseOrderStock(c,orderId,true);}await c.query('INSERT INTO order_status_history(order_id,status,actor_type,actor_id) VALUES($1,$2,\'RIDER\',$3)',[orderId,b.status,this.userId(h)]);await this.notifyOrderStatus(orderId,b.status);realtime.emit('order:update',{orderId,status:b.status,updatedAt:new Date().toISOString()});return {orderId,status:b.status};}); await this.notifyOrderStatus(result.orderId,result.status); realtime.emit('order:update',{orderId:result.orderId,status:result.status,updatedAt:new Date().toISOString()}); return this.orderById(result.orderId);
  }

  @Post('admin/dispatch/run') async dispatch(@Headers() h:any){
    await this.actor(h,['ADMIN','SUPER_ADMIN']);
    const assigned=await this.db.tx(async c=>{
      const riders=(await c.query(`SELECT * FROM riders WHERE is_online=true ORDER BY last_location_at DESC NULLS LAST`)).rows;
      const orders=(await c.query(`SELECT o.id,o.merchant_id,m.village,m.delivery_fee FROM orders o JOIN merchants m ON m.id=o.merchant_id WHERE o.status='READY_FOR_PICKUP' AND NOT EXISTS(SELECT 1 FROM deliveries d WHERE d.order_id=o.id) ORDER BY o.created_at ASC LIMIT 50 FOR UPDATE OF o`)).rows;
      const assigned:any[]=[];
      for(const o of orders){
        const target=(await c.query('SELECT a.latitude,a.longitude FROM orders o LEFT JOIN addresses a ON a.id=o.address_id WHERE o.id=$1',[o.id])).rows[0];
        let candidates=riders.filter((x:any)=>!assigned.some(a=>a.rider_id===x.id));
        if(!candidates.length) continue;
        if(target?.latitude!=null && target?.longitude!=null){ const withLocation=candidates.filter((x:any)=>x.latitude!=null&&x.longitude!=null); if(withLocation.length) candidates=withLocation; candidates.sort((a:any,b:any)=>distanceKm(Number(a.latitude||0),Number(a.longitude||0),Number(target.latitude),Number(target.longitude))-distanceKm(Number(b.latitude||0),Number(b.longitude||0),Number(target.latitude),Number(target.longitude))); }
        const r=candidates[0];
        await c.query('INSERT INTO deliveries(order_id,rider_id,assigned_at) VALUES($1,$2,now())',[o.id,r.id]);
        await c.query("UPDATE orders SET status='ASSIGNED_RIDER',updated_at=now() WHERE id=$1",[o.id]);
        await c.query("INSERT INTO order_status_history(order_id,status,actor_type,actor_id) VALUES($1,'ASSIGNED_RIDER','DISPATCH',$2)",[o.id,r.user_id]);
        assigned.push({order_id:o.id,rider_id:r.id});
      }
      return assigned;
    });
    for(const item of assigned) await this.notifyOrderStatus(item.order_id,'ASSIGNED_RIDER');
    return {assigned,count:assigned.length};
  }
  @Get('admin/orders') async adminOrders(@Headers() h:any,@Query('status') status?:string){ await this.actor(h,['ADMIN','SUPER_ADMIN']); const p:any[]=[];let sql=`SELECT o.*,m.name merchant_name,u.phone customer_phone FROM orders o JOIN merchants m ON m.id=o.merchant_id JOIN users u ON u.id=o.user_id`;if(status){p.push(status);sql+=' WHERE o.status=$1'}sql+=' ORDER BY o.created_at DESC LIMIT 200';return (await this.db.query(sql,p)).rows; }
  @Get('admin/merchants') async adminMerchants(@Headers() h:any){ await this.actor(h,['ADMIN','SUPER_ADMIN']); return (await this.db.query(`SELECT m.*,count(p.id)::int product_count FROM merchants m LEFT JOIN products p ON p.merchant_id=m.id GROUP BY m.id ORDER BY m.created_at DESC`)).rows; }

  @Get('tracking/:orderId') async tracking(@Param('orderId') orderId:string,@Headers() h:any){
    const userId=this.userId(h);
    const o=(await this.db.query(`SELECT o.id,o.status,o.updated_at,d.rider_id,r.latitude,r.longitude,r.last_location_at FROM orders o LEFT JOIN deliveries d ON d.order_id=o.id LEFT JOIN riders r ON r.id=d.rider_id WHERE o.id=$1 AND o.user_id=$2`,[orderId,userId])).rows[0];
    if(!o) throw new NotFoundException('الطلب غير موجود');
    const history=(await this.db.query('SELECT status,actor_type,created_at FROM order_status_history WHERE order_id=$1 ORDER BY created_at',[orderId])).rows;
    return {orderId:o.id,status:o.status,updatedAt:o.updated_at,rider:o.rider_id?{id:o.rider_id,latitude:o.latitude,longitude:o.longitude,lastLocationAt:o.last_location_at}:null,history};
  }
  @Get('tracking/:orderId/route') async trackingRoute(@Param('orderId') orderId:string,@Headers() h:any){
    const userId=this.userId(h);
    const r=(await this.db.query(`SELECT o.id,o.status,r.latitude rider_latitude,r.longitude rider_longitude,a.latitude dest_latitude,a.longitude dest_longitude FROM orders o LEFT JOIN deliveries d ON d.order_id=o.id LEFT JOIN riders r ON r.id=d.rider_id LEFT JOIN addresses a ON a.id=o.address_id WHERE o.id=$1 AND o.user_id=$2`,[orderId,userId])).rows[0];
    if(!r) throw new NotFoundException('الطلب غير موجود');
    let etaMinutes:null|number=null, distanceKmValue:null|number=null;
    if(r.rider_latitude!=null && r.rider_longitude!=null && r.dest_latitude!=null && r.dest_longitude!=null){
      distanceKmValue=Number(distanceKm(Number(r.rider_latitude),Number(r.rider_longitude),Number(r.dest_latitude),Number(r.dest_longitude)).toFixed(2));
      etaMinutes=Math.max(1,Math.ceil((distanceKmValue/25)*60));
    }
    return {orderId,status:r.status,from:r.rider_latitude!=null?{latitude:Number(r.rider_latitude),longitude:Number(r.rider_longitude)}:null,to:r.dest_latitude!=null?{latitude:Number(r.dest_latitude),longitude:Number(r.dest_longitude)}:null,distanceKm:distanceKmValue,etaMinutes};
  }
  @Get('tracking/:orderId/locations') async trackingLocations(@Param('orderId') orderId:string,@Headers() h:any){
    const userId=this.userId(h);
    const ok=await this.db.query('SELECT 1 FROM orders WHERE id=$1 AND user_id=$2',[orderId,userId]); if(!ok.rowCount) throw new NotFoundException('الطلب غير موجود');
    return (await this.db.query('SELECT latitude,longitude,accuracy,recorded_at FROM rider_location_events WHERE order_id=$1 ORDER BY recorded_at DESC LIMIT 100',[orderId])).rows;
  }
  @Post('rider/orders/:orderId/proof') async riderProof(@Param('orderId') orderId:string,@Headers() h:any,@Body() b:any){
    await this.actor(h,['RIDER','ADMIN','SUPER_ADMIN']);
    if(!b?.proofUrl) throw new BadRequestException('proofUrl مطلوب');
    const r=await this.db.query(`UPDATE deliveries d SET proof_url=$1 FROM riders r WHERE d.order_id=$2 AND d.rider_id=r.id AND r.user_id=$3 RETURNING d.*`,[b.proofUrl,orderId,this.userId(h)]);
    if(!r.rowCount) throw new NotFoundException('التسليم غير موجود'); return r.rows[0];
  }
  @Post('reviews') async review(@Headers() h:any,@Body() b:any){ const userId=this.userId(h); if(String(b?.comment||'').length>2000) throw new BadRequestException('التعليق طويل جدًا'); if(!b?.orderId||!Number.isInteger(Number(b.rating))||Number(b.rating)<1||Number(b.rating)>5)throw new BadRequestException('التقييم غير صالح'); return this.db.tx(async c=>{const o=(await c.query(`SELECT * FROM orders WHERE id=$1 AND user_id=$2 AND status='DELIVERED'`,[b.orderId,userId])).rows[0];if(!o)throw new BadRequestException('لا يمكن تقييم هذا الطلب');const existing=(await c.query('SELECT 1 FROM reviews WHERE order_id=$1 AND user_id=$2',[b.orderId,userId])).rowCount;if(existing) throw new ConflictException('تم تقييم هذا الطلب بالفعل');const r=(await c.query('INSERT INTO reviews(order_id,user_id,merchant_id,rating,comment) VALUES($1,$2,$3,$4,$5) RETURNING *',[b.orderId,userId,o.merchant_id,b.rating,b.comment||null])).rows[0];await c.query(`UPDATE merchants SET rating=ROUND(((rating*GREATEST((SELECT count(*) FROM reviews WHERE merchant_id=$1)-1,0))+ $2)/(SELECT count(*) FROM reviews WHERE merchant_id=$1),1) WHERE id=$1`,[o.merchant_id,b.rating]);return r;}); }
  @Post('support/tickets') async support(@Headers() h:any,@Body() b:any){const userId=this.userId(h);if(!b?.subject||!b?.message||String(b.subject).length>180||String(b.message).length>5000)throw new BadRequestException('بيانات البلاغ ناقصة أو طويلة');if(b.orderId){const owned=await this.db.query('SELECT 1 FROM orders WHERE id=$1 AND user_id=$2',[b.orderId,userId]);if(!owned.rowCount)throw new NotFoundException('الطلب غير موجود');}const priority=['LOW','NORMAL','HIGH'].includes(String(b.priority||'NORMAL'))?String(b.priority||'NORMAL'):'NORMAL';const t=(await this.db.query('INSERT INTO support_tickets(user_id,order_id,subject,message,priority) VALUES($1,$2,$3,$4,$5) RETURNING *',[userId,b.orderId||null,b.subject,b.message,priority])).rows[0]; await this.notifyUser(this.userId(h),'SUPPORT','تم فتح بلاغ الدعم',`رقم البلاغ ${t.id} تم استلامه.`,{ticketId:t.id},`SUPPORT_CREATED:${t.id}`); return t;}
  @Get('support/tickets') async myTickets(@Headers() h:any){return (await this.db.query('SELECT * FROM support_tickets WHERE user_id=$1 ORDER BY created_at DESC',[this.userId(h)])).rows;}
  @Get('admin/support/tickets') async adminTickets(@Headers() h:any,@Query('status') status?:string){await this.actor(h,['ADMIN','SUPER_ADMIN']);const p:any[]=[];let sql='SELECT s.*,u.name user_name,u.phone FROM support_tickets s JOIN users u ON u.id=s.user_id';if(status){p.push(status);sql+=' WHERE s.status=$1';}sql+=' ORDER BY s.created_at DESC LIMIT 200';return (await this.db.query(sql,p)).rows;}
  @Patch('admin/support/tickets/:id') async updateTicket(@Param('id') id:string,@Headers() h:any,@Body() b:any){await this.actor(h,['ADMIN','SUPER_ADMIN']);if(!['OPEN','IN_PROGRESS','RESOLVED','CLOSED'].includes(b?.status))throw new BadRequestException('حالة غير صالحة');const r=await this.db.query('UPDATE support_tickets SET status=$1,updated_at=now() WHERE id=$2 RETURNING *',[b.status,id]);if(!r.rowCount)throw new NotFoundException('البلاغ غير موجود');await this.notifyUser(r.rows[0].user_id,'SUPPORT','تحديث على بلاغ الدعم',`حالة البلاغ أصبحت ${b.status}.`,{ticketId:id,status:b.status},`SUPPORT_STATUS:${id}:${b.status}`);return r.rows[0];}
  @Post('admin/support/tickets/:id/messages') async supportMessage(@Param('id') id:string,@Headers() h:any,@Body() b:any){const actor=await this.actor(h,['ADMIN','SUPER_ADMIN']);if(!b?.message)throw new BadRequestException('الرسالة مطلوبة');const r=await this.db.query('INSERT INTO support_ticket_messages(ticket_id,author_user_id,body) VALUES($1,$2,$3) RETURNING *',[id,actor.id,b.message]);const t=(await this.db.query('SELECT user_id FROM support_tickets WHERE id=$1',[id])).rows[0];if(t) await this.notifyUser(t.user_id,'SUPPORT','رسالة جديدة من الدعم',String(b.message).slice(0,180),{ticketId:id},`SUPPORT_MESSAGE:${id}:${r.rows[0].id}`);return r.rows[0];}
  @Get('support/tickets/:id/messages') async ticketMessages(@Param('id') id:string,@Headers() h:any){const uid=this.userId(h);const allowed=(await this.db.query('SELECT 1 FROM support_tickets WHERE id=$1 AND user_id=$2',[id,uid])).rowCount; if(!allowed) throw new NotFoundException('البلاغ غير موجود'); return (await this.db.query('SELECT * FROM support_ticket_messages WHERE ticket_id=$1 ORDER BY created_at',[id])).rows;}
  @Post('devices/push-token') async registerPushToken(@Headers() h:any,@Body() b:any){ const userId=this.userId(h); if(!b?.token||!['ANDROID','IOS','WEB'].includes(b.platform)) throw new BadRequestException('بيانات الجهاز غير صالحة'); await this.db.query(`INSERT INTO device_tokens(user_id,token,platform) VALUES($1,$2,$3) ON CONFLICT(token) DO UPDATE SET user_id=EXCLUDED.user_id,platform=EXCLUDED.platform,updated_at=now()`,[userId,b.token,b.platform]); return {success:true}; }
  @Delete('devices/push-token/:token') async removePushToken(@Headers() h:any,@Param('token') token:string){ const userId=this.userId(h); await this.db.query('DELETE FROM device_tokens WHERE user_id=$1 AND token=$2',[userId,token]); return {success:true}; }
  @Post('payments/intent') async paymentIntent(@Headers() h:any,@Body() b:any){
    const userId=this.userId(h); const o=(await this.db.query('SELECT * FROM orders WHERE id=$1 AND user_id=$2',[b?.orderId,userId])).rows[0];
    if(!o)throw new NotFoundException('الطلب غير موجود');
    if(String(b?.method||'').toUpperCase()!=='CASH') throw new BadRequestException('الدفع عند الاستلام هو وسيلة الدفع الوحيدة حاليًا');
    if(String(process.env.PAYMENT_PROVIDER||'cod').toLowerCase()!=='cod') throw new ServiceUnavailableException('وضع الدفع عند الاستلام غير مضبوط');
    const existing=(await this.db.query('SELECT * FROM payments WHERE order_id=$1 AND user_id=$2 AND method=$3 AND status=\'PENDING\' ORDER BY created_at DESC LIMIT 1',[o.id,userId,b.method])).rows[0]; const p=existing || (await this.db.query(`INSERT INTO payments(order_id,user_id,method,status,amount,currency,provider) VALUES($1,$2,$3,'PENDING',$4,'EGP',$5) RETURNING *`,[o.id,userId,b.method,o.total,process.env.PAYMENT_PROVIDER||'cod'])).rows[0];
    const intent=await this.integrations.payments.createIntent({paymentId:p.id,amount:Number(o.total),currency:'EGP',method:b.method,orderId:o.id,returnUrl:b.returnUrl});
    if(intent.providerReference) await this.db.query('UPDATE payments SET provider_reference=$1,updated_at=now() WHERE id=$2',[intent.providerReference,p.id]);
    if(b.method==='CASH') { const fresh=(await this.db.query('SELECT status FROM orders WHERE id=$1',[o.id])).rows[0]; if(fresh?.status==='CREATED'){ await this.db.tx(async c=>{ await c.query("UPDATE orders SET status='CONFIRMED',updated_at=now() WHERE id=$1 AND status='CREATED'",[o.id]); await c.query("INSERT INTO order_status_history(order_id,status,actor_type,actor_id) VALUES($1,'CONFIRMED','CUSTOMER',$2)",[o.id,userId]); }); await this.notifyOrderStatus(o.id,'CONFIRMED'); } }
    const payment=(await this.db.query('SELECT * FROM payments WHERE id=$1',[p.id])).rows[0];
    return {payment,nextAction:b.method==='CASH'?'NONE':(intent.checkoutUrl?'REDIRECT':'CONNECT_PROVIDER'),checkoutUrl:intent.checkoutUrl||null};
  }
  @Post('payments/:id/confirm') async confirmPayment(@Headers() h:any,@Param('id') id:string,@Body() b:any){ const userId=this.userId(h); const p=(await this.db.query('SELECT * FROM payments WHERE id=$1 AND user_id=$2',[id,userId])).rows[0]; if(!p) throw new NotFoundException('عملية الدفع غير موجودة'); if(p.method!=='CASH') throw new ForbiddenException('تأكيد الدفع الإلكتروني يتم من مزود الدفع فقط'); return p; }
  @Get('payments/:id') async payment(@Headers() h:any,@Param('id') id:string){ const r=await this.db.query('SELECT * FROM payments WHERE id=$1 AND user_id=$2',[id,this.userId(h)]); if(!r.rowCount)throw new NotFoundException('عملية الدفع غير موجودة'); return r.rows[0]; }
  @Post('maps/route') async mapsRoute(@Headers() h:any,@Body() b:any){ await this.userId(h); if(!b?.from||!b?.to) throw new BadRequestException('from/to مطلوبان'); const from={lat:Number(b.from.latitude??b.from.lat),lon:Number(b.from.longitude??b.from.lon)},to={lat:Number(b.to.latitude??b.to.lat),lon:Number(b.to.longitude??b.to.lon)}; if(!validLatLon(from.lat,from.lon)||!validLatLon(to.lat,to.lon)) throw new BadRequestException('إحداثيات المسار غير صالحة'); return this.integrations.maps.route(from,to); }
  @Post('storage/upload-target') async storageTarget(@Headers() h:any,@Body() b:any){ const actor=await this.actor(h,['MERCHANT','RIDER','ADMIN','SUPER_ADMIN']); const key=String(b?.key||'').trim(); const contentType=String(b?.contentType||'').trim().toLowerCase(); if(!key||!contentType) throw new BadRequestException('key/contentType مطلوبان'); if(key.length>300||key.includes('..')||key.startsWith('/')||!/^[a-zA-Z0-9._\/-]+$/.test(key)) throw new BadRequestException('مسار الملف غير صالح'); if(!['image/jpeg','image/png','image/webp','image/jpg'].includes(contentType)) throw new BadRequestException('نوع الملف غير مسموح'); const scopedKey=['ADMIN','SUPER_ADMIN'].includes(actor.role)?key:`${actor.id}/${key}`; return this.integrations.storage.createUploadTarget({key:scopedKey,contentType}); }
  @Post('payments/webhook') async paymentWebhook(@Headers() h:any,@Req() req:any){ if(String(process.env.PAYMENT_PROVIDER||'cod').toLowerCase()==='cod') throw new BadRequestException('Webhook غير مستخدم مع الدفع عند الاستلام'); const raw=req.rawBody||Buffer.from(JSON.stringify(req.body||{})); const result=this.integrations.payments.verifyWebhook(raw,h['x-payment-signature']); if(!result.valid) throw new UnauthorizedException('توقيع الدفع غير صالح'); return {received:true}; }
  @Post('admin/delivery-zones') async createZone(@Headers() h:any,@Body() b:any){
    await this.actor(h,['ADMIN','SUPER_ADMIN']);
    if(!b?.name || b.latitude==null || b.longitude==null) throw new BadRequestException('بيانات المنطقة ناقصة');
    if(!validLatLon(b.latitude,b.longitude)) throw new BadRequestException('إحداثيات المنطقة غير صالحة');
    const radius=Number(b.radiusKm??8), base=Number(b.baseFee??15), perKm=Number(b.perKmFee??3), min=Number(b.minFee??15); if(![radius,base,perKm,min].every(Number.isFinite)||radius<=0||radius>100||base<0||perKm<0||min<0) throw new BadRequestException('قيم رسوم المنطقة غير صالحة');
    return (await this.db.query(`INSERT INTO delivery_zones(name,center_latitude,center_longitude,radius_km,base_fee,per_km_fee,min_fee,is_active) VALUES($1,$2,$3,$4,$5,$6,$7,COALESCE($8,true)) RETURNING *`,[b.name,b.latitude,b.longitude,b.radiusKm||8,b.baseFee||15,b.perKmFee||3,b.minFee||15,b.isActive])).rows[0];
  }
  @Patch('admin/delivery-zones/:id') async updateZone(@Param('id') id:string,@Headers() h:any,@Body() b:any){
    await this.actor(h,['ADMIN','SUPER_ADMIN']); if(b.latitude!==undefined||b.longitude!==undefined){if(!validLatLon(b.latitude,b.longitude)) throw new BadRequestException('إحداثيات المنطقة غير صالحة');} for(const [k,max] of [['radiusKm',100],['baseFee',1000000],['perKmFee',1000000],['minFee',1000000]] as any[]){if(b[k]!==undefined && (!Number.isFinite(Number(b[k]))||Number(b[k])<0||Number(b[k])>max)) throw new BadRequestException('قيمة المنطقة غير صالحة');} const map:any={name:'name',latitude:'center_latitude',longitude:'center_longitude',radiusKm:'radius_km',baseFee:'base_fee',perKmFee:'per_km_fee',minFee:'min_fee',isActive:'is_active'}; const fields:string[]=[]; const vals:any[]=[];
    for(const [k,col] of Object.entries(map)){ if(b[k]!==undefined){ vals.push(b[k]); fields.push(`${col}=$${vals.length}`); } }
    if(!fields.length) throw new BadRequestException('لا توجد تغييرات'); fields.push('updated_at=now()'); vals.push(id);
    const r=await this.db.query(`UPDATE delivery_zones SET ${fields.join(',')} WHERE id=$${vals.length} RETURNING *`,vals); if(!r.rowCount) throw new NotFoundException('المنطقة غير موجودة'); return r.rows[0];
  }
  @Get('admin/delivery-zones') async adminZones(@Headers() h:any){ await this.actor(h,['ADMIN','SUPER_ADMIN']); return (await this.db.query('SELECT * FROM delivery_zones ORDER BY name')).rows; }
  @Get('admin/operations/summary') async operationsSummary(@Headers() h:any){ await this.actor(h,['ADMIN','SUPER_ADMIN']);
    const [status,zones,riders,merchants]=await Promise.all([
      this.db.query(`SELECT status,count(*)::int count FROM orders GROUP BY status ORDER BY status`),
      this.db.query(`SELECT z.name,z.is_active,COUNT(o.id)::int orders,COALESCE(SUM(o.total) FILTER(WHERE o.status='DELIVERED'),0) revenue FROM delivery_zones z LEFT JOIN addresses a ON a.latitude IS NOT NULL AND a.longitude IS NOT NULL LEFT JOIN orders o ON o.address_id=a.id GROUP BY z.id ORDER BY z.name`),
      this.db.query(`SELECT COUNT(*)::int total,COUNT(*) FILTER(WHERE is_online)::int online,COUNT(*) FILTER(WHERE is_online AND last_location_at>now()-interval '10 minutes')::int active_recent FROM riders`),
      this.db.query(`SELECT COUNT(*)::int total,COUNT(*) FILTER(WHERE is_active)::int active FROM merchants`)
    ]);
    return {ordersByStatus:status.rows,zones:zones.rows,riders:riders.rows[0],merchants:merchants.rows[0]};
  }

  @Get('admin/analytics') async analytics(@Headers() h:any,@Query('days') days='30'){
    await this.actor(h,['ADMIN','SUPER_ADMIN']);
    const n=Math.min(365,Math.max(1,Number(days)||30));
    const commissionRate=Math.max(0,Math.min(1,Number(process.env.PLATFORM_COMMISSION_RATE||0.10)));
    const [summary,daily,merchants,riders,zones,payments]=await Promise.all([
      this.db.query(`SELECT COUNT(*)::int orders, COUNT(*) FILTER(WHERE status='DELIVERED')::int delivered,
        COUNT(*) FILTER(WHERE status IN ('CANCELLED','REJECTED','FAILED_PAYMENT'))::int failed,
        COALESCE(SUM(total) FILTER(WHERE status='DELIVERED'),0)::numeric revenue,
        COALESCE(SUM(subtotal) FILTER(WHERE status='DELIVERED'),0)::numeric subtotal_revenue,
        COALESCE(SUM(delivery_fee) FILTER(WHERE status='DELIVERED'),0)::numeric delivery_revenue
        FROM orders WHERE created_at >= now()-($1::text || ' days')::interval`,[n]),
      this.db.query(`SELECT date_trunc('day',created_at)::date day, COUNT(*)::int orders,
        COUNT(*) FILTER(WHERE status='DELIVERED')::int delivered,
        COALESCE(SUM(total) FILTER(WHERE status='DELIVERED'),0)::numeric revenue
        FROM orders WHERE created_at >= now()-($1::text || ' days')::interval GROUP BY 1 ORDER BY 1`,[n]),
      this.db.query(`SELECT m.id,m.name,m.village,COUNT(o.id)::int orders,
        COUNT(o.id) FILTER(WHERE o.status='DELIVERED')::int delivered,
        COALESCE(SUM(o.total) FILTER(WHERE o.status='DELIVERED'),0)::numeric revenue,
        COALESCE(AVG(o.total) FILTER(WHERE o.status='DELIVERED'),0)::numeric avg_order_value,
        m.rating FROM merchants m LEFT JOIN orders o ON o.merchant_id=m.id AND o.created_at >= now()-($1::text || ' days')::interval
        GROUP BY m.id ORDER BY revenue DESC`,[n]),
      this.db.query(`SELECT r.id,u.name,u.phone,r.is_online,COUNT(d.id)::int deliveries,
        COUNT(d.id) FILTER(WHERE o.status='DELIVERED')::int delivered,
        COALESCE(SUM(o.delivery_fee) FILTER(WHERE o.status='DELIVERED'),0)::numeric delivery_fees,
        MAX(d.delivered_at) last_delivery FROM riders r JOIN users u ON u.id=r.user_id
        LEFT JOIN deliveries d ON d.rider_id=r.id AND d.assigned_at >= now()-($1::text || ' days')::interval
        LEFT JOIN orders o ON o.id=d.order_id GROUP BY r.id,u.id ORDER BY delivered DESC`,[n]),
      this.db.query(`SELECT z.id,z.name,z.radius_km,z.base_fee,z.per_km_fee,z.is_active,COUNT(o.id)::int orders,
        COUNT(o.id) FILTER(WHERE o.status='DELIVERED')::int delivered,
        COALESCE(SUM(o.total) FILTER(WHERE o.status='DELIVERED'),0)::numeric revenue
        FROM delivery_zones z LEFT JOIN addresses a ON a.latitude IS NOT NULL AND a.longitude IS NOT NULL
        LEFT JOIN orders o ON o.address_id=a.id AND o.created_at >= now()-($1::text || ' days')::interval
        GROUP BY z.id ORDER BY revenue DESC`,[n]),
      this.db.query(`SELECT method,status,COUNT(*)::int count,COALESCE(SUM(amount),0)::numeric amount FROM payments
        WHERE created_at >= now()-($1::text || ' days')::interval GROUP BY method,status ORDER BY method,status`,[n])
    ]);
    const s=summary.rows[0];
    return {days:n,commissionRate,summary:{...s,platformCommission:Number(s.revenue)*commissionRate},daily:daily.rows,merchants:merchants.rows,riders:riders.rows,zones:zones.rows,payments:payments.rows};
  }
  @Get('admin/analytics/csv') async analyticsCsv(@Headers() h:any,@Query('days') days='30'){
    const data=await this.analytics(h,days);
    const rows=[['date','orders','delivered','revenue']];
    for(const r of data.daily) rows.push([String(r.day),String(r.orders),String(r.delivered),String(r.revenue)]);
    return rows.map(r=>r.map(v=>`"${String(v).replace(/"/g,'""')}"`).join(',')).join('\n');
  }

  @Get('admin/audit-logs') async auditLogs(@Headers() h:any,@Query('limit') limit='100'){ await this.actor(h,['ADMIN','SUPER_ADMIN']); const n=Math.min(200,Math.max(1,Number(limit)||100)); return (await this.db.query('SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT $1',[n])).rows; }
  @Get('admin/launch/status') async launchStatus(@Headers() h:any){
    await this.actor(h,['ADMIN','SUPER_ADMIN']);
    const [db,stale,ready,riders,support,stock,payments]=await Promise.all([
      this.db.query('SELECT now() db_time, current_database() database'),
      this.db.query(`SELECT COUNT(*)::int count FROM orders WHERE status NOT IN ('DELIVERED','CANCELLED','REJECTED','FAILED_PAYMENT','REFUNDED') AND updated_at < now()-interval '45 minutes'`),
      this.db.query(`SELECT COUNT(*)::int count FROM orders WHERE status='READY_FOR_PICKUP' AND NOT EXISTS (SELECT 1 FROM deliveries d WHERE d.order_id=orders.id)`),
      this.db.query(`SELECT COUNT(*)::int total, COUNT(*) FILTER(WHERE is_online)::int online, COUNT(*) FILTER(WHERE is_online AND last_location_at < now()-interval '10 minutes')::int stale_online FROM riders`),
      this.db.query(`SELECT COUNT(*)::int open FROM support_tickets WHERE status IN ('OPEN','IN_PROGRESS')`),
      this.db.query(`SELECT COUNT(*)::int low_stock FROM products WHERE is_available=true AND stock_quantity-stock_reserved <= low_stock_threshold`),
      this.db.query(`SELECT COUNT(*)::int failed_recent FROM payments WHERE status='FAILED' AND created_at >= now()-interval '24 hours'`)
    ]);
    const integrations=this.integrations.status();
    const checks={database:true,integrations:Object.values(integrations).every((x:any)=>x.configured),staleOrders:Number(stale.rows[0].count)===0,unassignedReady:Number(ready.rows[0].count)===0};
    return {ready:Object.values(checks).every(Boolean),checks,integrations,orders:{stale:Number(stale.rows[0].count),unassignedReady:Number(ready.rows[0].count)},riders:riders.rows[0],supportOpen:Number(support.rows[0].open),lowStock:Number(stock.rows[0].low_stock),failedPayments24h:Number(payments.rows[0].failed_recent),database:db.rows[0]};
  }

  @Get('admin/metrics') async metrics(@Headers() h:any){ await this.actor(h,['ADMIN','SUPER_ADMIN']); const r=await this.db.query(`SELECT (SELECT count(*) FROM users) users,(SELECT count(*) FROM merchants) merchants,(SELECT count(*) FROM products) products,(SELECT count(*) FROM orders) orders,(SELECT count(*) FROM orders WHERE status='DELIVERED') delivered,COALESCE((SELECT sum(total) FROM orders WHERE status='DELIVERED'),0) revenue`); return r.rows[0]; }
}



@WebSocketGateway({ namespace: '/realtime', cors: { origin: process.env.CORS_ORIGINS ? API_ALLOWED_ORIGINS : (!isProduction) } })
class RealtimeGateway {
  @WebSocketServer() server!: Server;
  constructor(private db:Db){
    realtime.on('order:update', (event:any) => { if(this.server) this.server.to(`order:${event.orderId}`).emit('order:update', event); });
    realtime.on('order:location', (event:any) => { if(this.server) this.server.to(`order:${event.orderId}`).emit('order:location', event); });
  }
  @SubscribeMessage('order:join') async join(@MessageBody() body:any, @ConnectedSocket() socket:Socket){
    if(!body?.orderId) return {ok:false};
    const token=String(body?.accessToken||''); const p=verifyToken(token); if(!p?.sub) return {ok:false,error:'unauthorized'}; const access=await this.db.query('SELECT 1 FROM orders WHERE id=$1 AND user_id=$2',[body.orderId,p.sub]); if(!access.rowCount) return {ok:false,error:'forbidden'}; socket.data.userId=p.sub; socket.join(`order:${body.orderId}`); return {ok:true,orderId:body.orderId};
  }
  @SubscribeMessage('order:leave') leave(@MessageBody() body:any, @ConnectedSocket() socket:Socket){
    if(body?.orderId) socket.leave(`order:${body.orderId}`); return {ok:true};
  }
}



@Module({controllers:[AppController],providers:[Db,RealtimeGateway,IntegrationService]}) class AppModule{}



@Catch()
class ApiExceptionFilter implements ExceptionFilter{
  catch(exception:any,host:ArgumentsHost){
    const res=host.switchToHttp().getResponse();
    const req=host.switchToHttp().getRequest();
    if(exception?.code==='22P02') return res.status(400).json({statusCode:400,message:'بيانات غير صالحة',requestId:req.requestId});
    if(exception?.code==='23505') return res.status(409).json({statusCode:409,message:'البيانات موجودة بالفعل',requestId:req.requestId});
    if(exception instanceof HttpException){const status=exception.getStatus();const body=exception.getResponse();return res.status(status).json(typeof body==='string'?{statusCode:status,message:body,requestId:req.requestId}:{...body,requestId:req.requestId});}
    console.error(JSON.stringify({event:'unhandled_exception',requestId:req.requestId,error:String(exception?.message||exception)}));
    return res.status(500).json({statusCode:500,message:'حدث خطأ داخلي',requestId:req.requestId});
  }
}

async function bootstrap(){
  const app=await NestFactory.create(AppModule,{rawBody:true});
  app.getHttpAdapter().getInstance().set('trust proxy', 1);
  app.useGlobalFilters(new ApiExceptionFilter());
  app.use((req:any,res:any,next:any)=>{ res.setHeader('X-Content-Type-Options','nosniff'); res.setHeader('X-Frame-Options','DENY'); res.setHeader('Referrer-Policy','no-referrer'); res.setHeader('Permissions-Policy','geolocation=(),camera=(),microphone=()'); next(); });
  app.enableCors({origin:(origin,cb)=>{ if(!origin) return cb(null,true); if(API_ALLOWED_ORIGINS.includes(origin)) return cb(null,true); if(!isProduction && API_ALLOWED_ORIGINS.length===0) return cb(null,true); return cb(new Error('CORS origin denied'),false);}, credentials:true});
  app.setGlobalPrefix('api/v1');
  app.use((req:any,res:any,next:any)=>{
    const incoming=String(req.headers['x-request-id']||'');
    const requestId=/^[0-9a-fA-F-]{20,80}$/.test(incoming) ? incoming : randomUUID();
    req.requestId=requestId; res.setHeader('x-request-id',requestId);
    const started=Date.now();
    res.on('finish',()=>console.log(JSON.stringify({event:'http_request',requestId,method:req.method,path:req.originalUrl,status:res.statusCode,durationMs:Date.now()-started})));
    next();
  });
  app.use((req:any,res:any,next:any)=>{ if(req.path==='/api/v1/health'||req.path==='/api/v1/health/ready') return next(); const key=String(req.ip||req.headers['x-forwarded-for']||'unknown').split(',')[0]; const now=Date.now(); const b=rateBuckets.get(key); if(!b||now-b.start>=RATE_LIMIT_WINDOW_MS){rateBuckets.set(key,{start:now,count:1}); return next();} b.count++; if(b.count>RATE_LIMIT_MAX){res.status(429).json({statusCode:429,message:'طلبات كثيرة مؤقتًا',requestId:req.requestId});return;} next(); });
  await app.listen(Number(process.env.PORT||3000));
  console.log(JSON.stringify({event:'server_started',version:API_VERSION,port:Number(process.env.PORT||3000),nodeEnv:process.env.NODE_ENV||'development'}));
}
bootstrap();
