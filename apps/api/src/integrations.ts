import { Injectable, BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import { createHmac, randomInt, timingSafeEqual } from 'crypto';

export type OtpSendResult = { provider: string; code: string; providerReference?: string };
export interface OtpProvider { sendOtp(phone: string, code: string): Promise<OtpSendResult>; }
export interface PushProvider { send(input: { token: string; title: string; body: string; data?: Record<string,string> }): Promise<{ provider: string; providerReference?: string }>; }
export interface MapsProvider { route(from: {lat:number;lon:number}, to: {lat:number;lon:number}): Promise<{distanceKm:number; durationMinutes:number; provider:string}>; geocode?(query:string): Promise<{lat:number;lon:number;displayName:string;provider:string}[]>; }
export interface PaymentProvider { createIntent(input: {paymentId:string; amount:number; currency:string; method:string; orderId:string; returnUrl?:string}): Promise<{provider:string; providerReference?:string; checkoutUrl?:string; raw?:any}>; verifyWebhook(payload:string|Buffer, signature?:string): any; }
export interface ObjectStorageProvider { createUploadTarget(input:{key:string;contentType:string}): Promise<{provider:string;uploadUrl?:string;objectUrl?:string;expiresIn?:number}>; }

async function postJson(url:string, body:any, headers:Record<string,string>={}) {
  const res = await fetch(url, { method:'POST', headers:{'content-type':'application/json', ...headers}, body:JSON.stringify(body) });
  const text = await res.text();
  let data:any; try { data = text ? JSON.parse(text) : {}; } catch { data = { raw:text }; }
  if (!res.ok) throw new Error(`provider_http_${res.status}`);
  return data;
}

@Injectable()
export class ConsoleOtpProvider implements OtpProvider {
  async sendOtp(phone:string, code:string){ console.log(`[JAYEK OTP] ${phone}: ${code}`); return {provider:'console',code}; }
}

@Injectable()
export class GenericHttpOtpProvider implements OtpProvider {
  async sendOtp(phone:string, code:string){
    const url=process.env.OTP_HTTP_URL;
    if(!url) throw new ServiceUnavailableException('OTP_HTTP_URL غير مضبوط');
    const data=await postJson(url,{phone,code,message:(process.env.OTP_MESSAGE_TEMPLATE||'رمز جايك: {code}').replace('{code}',code)},{authorization:process.env.OTP_HTTP_AUTH||''});
    return {provider:process.env.OTP_PROVIDER||'http',code,providerReference:data.id||data.reference};
  }
}

@Injectable()
export class ConsolePushProvider implements PushProvider {
  async send(input:{token:string;title:string;body:string;data?:Record<string,string>}){ console.log('[JAYEK PUSH]',input); return {provider:'console'}; }
}

@Injectable()
export class GenericHttpPushProvider implements PushProvider {
  async send(input:{token:string;title:string;body:string;data?:Record<string,string>}){
    const url=process.env.PUSH_HTTP_URL; if(!url) throw new ServiceUnavailableException('PUSH_HTTP_URL غير مضبوط');
    const data=await postJson(url,{token:input.token,title:input.title,body:input.body,data:input.data||{}},{authorization:process.env.PUSH_HTTP_AUTH||''});
    return {provider:process.env.PUSH_PROVIDER||'http',providerReference:data.id||data.reference};
  }
}

function haversineKm(a:{lat:number;lon:number},b:{lat:number;lon:number}){ const R=6371,toRad=(x:number)=>x*Math.PI/180;const dLat=toRad(b.lat-a.lat),dLon=toRad(b.lon-a.lon);const x=Math.sin(dLat/2)**2+Math.cos(toRad(a.lat))*Math.cos(toRad(b.lat))*Math.sin(dLon/2)**2;return 2*R*Math.asin(Math.sqrt(x)); }

@Injectable()
export class HaversineMapsProvider implements MapsProvider {
  async route(from:{lat:number;lon:number},to:{lat:number;lon:number}){ const distanceKm=haversineKm(from,to); return {distanceKm:Number(distanceKm.toFixed(2)),durationMinutes:Math.max(1,Math.ceil(distanceKm/25*60)),provider:'haversine'}; }
}

@Injectable()
export class GenericHttpMapsProvider implements MapsProvider {
  async route(from:{lat:number;lon:number},to:{lat:number;lon:number}){
    const url=process.env.MAPS_ROUTE_URL; if(!url) throw new ServiceUnavailableException('MAPS_ROUTE_URL غير مضبوط');
    const data=await postJson(url,{from,to},{authorization:process.env.MAPS_HTTP_AUTH||''});
    return {distanceKm:Number(data.distanceKm),durationMinutes:Number(data.durationMinutes),provider:process.env.MAP_PROVIDER||'http'};
  }
}

@Injectable()
export class CodPaymentProvider implements PaymentProvider {
  async createIntent(input:{paymentId:string;amount:number;currency:string;method:string;orderId:string}){ return {provider:'cod',providerReference:input.paymentId}; }
  verifyWebhook(){ return {valid:true}; }
}

@Injectable()
export class GenericHostedPaymentProvider implements PaymentProvider {
  async createIntent(input:{paymentId:string;amount:number;currency:string;method:string;orderId:string;returnUrl?:string}){
    const url=process.env.PAYMENT_CREATE_URL; if(!url) throw new ServiceUnavailableException('PAYMENT_CREATE_URL غير مضبوط');
    const data=await postJson(url,input,{authorization:process.env.PAYMENT_HTTP_AUTH||''});
    return {provider:process.env.PAYMENT_PROVIDER||'http',providerReference:data.reference||data.id,checkoutUrl:data.checkoutUrl||data.redirectUrl,raw:data};
  }
  verifyWebhook(payload:string|Buffer,signature?:string){
    const secret=process.env.PAYMENT_WEBHOOK_SECRET; if(!secret) throw new ServiceUnavailableException('PAYMENT_WEBHOOK_SECRET غير مضبوط');
    const expected=createHmac('sha256',secret).update(payload).digest('hex');
    if(!signature) return {valid:false};
    const supplied=Buffer.from(String(signature).trim(),'utf8');
    const expectedBuf=Buffer.from(expected,'utf8');
    return {valid:supplied.length===expectedBuf.length && timingSafeEqual(supplied,expectedBuf)};
  }
}

@Injectable()
export class LocalObjectStorageProvider implements ObjectStorageProvider {
  async createUploadTarget(input:{key:string;contentType:string}){ return {provider:'local',objectUrl:`/uploads/${encodeURIComponent(input.key)}`,expiresIn:3600}; }
}

@Injectable()
export class GenericS3StorageProvider implements ObjectStorageProvider {
  async createUploadTarget(input:{key:string;contentType:string}){
    if(!process.env.STORAGE_UPLOAD_URL) throw new ServiceUnavailableException('STORAGE_UPLOAD_URL غير مضبوط');
    return {provider:process.env.STORAGE_PROVIDER||'s3',uploadUrl:process.env.STORAGE_UPLOAD_URL,objectUrl:process.env.STORAGE_PUBLIC_BASE_URL ? `${process.env.STORAGE_PUBLIC_BASE_URL.replace(/\/$/,'')}/${input.key}` : undefined,expiresIn:900};
  }
}

@Injectable()
export class IntegrationService {
  readonly otp:OtpProvider;
  readonly push:PushProvider;
  readonly maps:MapsProvider;
  readonly payments:PaymentProvider;
  readonly storage:ObjectStorageProvider;
  constructor(){
    this.validateProductionConfig();
    this.otp=(process.env.OTP_PROVIDER||'console').toLowerCase()==='http'?new GenericHttpOtpProvider():new ConsoleOtpProvider();
    this.push=(process.env.PUSH_PROVIDER||'console').toLowerCase()==='http'?new GenericHttpPushProvider():new ConsolePushProvider();
    this.maps=(process.env.MAP_PROVIDER||'haversine').toLowerCase()==='http'?new GenericHttpMapsProvider():new HaversineMapsProvider();
    this.payments=(process.env.PAYMENT_PROVIDER||'cod').toLowerCase()==='http'?new GenericHostedPaymentProvider():new CodPaymentProvider();
    this.storage=(process.env.STORAGE_PROVIDER||'local').toLowerCase()==='s3'?new GenericS3StorageProvider():new LocalObjectStorageProvider();
  }

  validateProductionConfig(){
    if(process.env.NODE_ENV!=='production') return;
    const checks:[string,boolean][]=[
      ['OTP_PROVIDER=http',String(process.env.OTP_PROVIDER||'').toLowerCase()==='http' && Boolean(process.env.OTP_HTTP_URL && process.env.OTP_HTTP_AUTH)],
      ['PUSH_PROVIDER=http',String(process.env.PUSH_PROVIDER||'').toLowerCase()==='http' && Boolean(process.env.PUSH_HTTP_URL && process.env.PUSH_HTTP_AUTH)],
      ['MAP_PROVIDER=http',String(process.env.MAP_PROVIDER||'').toLowerCase()==='http' && Boolean(process.env.MAPS_ROUTE_URL)],
      ['STORAGE_PROVIDER=s3',String(process.env.STORAGE_PROVIDER||'').toLowerCase()==='s3' && Boolean(process.env.STORAGE_UPLOAD_URL && process.env.STORAGE_PUBLIC_BASE_URL)],
      ['PAYMENT_PROVIDER',String(process.env.PAYMENT_PROVIDER||'').toLowerCase()==='cod' || (String(process.env.PAYMENT_PROVIDER||'').toLowerCase()==='http' && Boolean(process.env.PAYMENT_CREATE_URL && process.env.PAYMENT_WEBHOOK_SECRET))],
      ['JWT_SECRET',Boolean(process.env.JWT_SECRET) && String(process.env.JWT_SECRET).length>=32 && process.env.JWT_SECRET!=='CHANGE_ME_LONG_RANDOM_SECRET'],
      ['CORS_ORIGINS',Boolean(process.env.CORS_ORIGINS && String(process.env.CORS_ORIGINS).trim())],
    ];
    const missing=checks.filter(([,ok])=>!ok).map(([name])=>name);
    if(missing.length) throw new Error(`Production integration configuration incomplete: ${missing.join(', ')}`);
  }
  status(){ return {
    otp:{provider:process.env.OTP_PROVIDER||'console',configured:process.env.OTP_PROVIDER==='http'?Boolean(process.env.OTP_HTTP_URL):true},
    push:{provider:process.env.PUSH_PROVIDER||'console',configured:process.env.PUSH_PROVIDER==='http'?Boolean(process.env.PUSH_HTTP_URL):true},
    maps:{provider:process.env.MAP_PROVIDER||'haversine',configured:process.env.MAP_PROVIDER==='http'?Boolean(process.env.MAPS_ROUTE_URL):true},
    payments:{provider:process.env.PAYMENT_PROVIDER||'cod',configured:process.env.PAYMENT_PROVIDER==='http'?Boolean(process.env.PAYMENT_CREATE_URL&&process.env.PAYMENT_WEBHOOK_SECRET):true},
    storage:{provider:process.env.STORAGE_PROVIDER||'local',configured:process.env.STORAGE_PROVIDER==='s3'?Boolean(process.env.STORAGE_UPLOAD_URL):true}
  }; }
  generateOtp(){ return String(randomInt(1000,10000)); }
}
