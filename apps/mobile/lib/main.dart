import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const primary=Color(0xFF176B4D), secondary=Color(0xFF65B87A), accent=Color(0xFFF39A3D), cream=Color(0xFFFFF8EA), ink=Color(0xFF202522);
const apiBase=String.fromEnvironment('JAYEK_API',defaultValue:'http://10.0.2.2:3000/api/v1');

class Api{
  String? token;
  String? userId;
  String? refreshToken;
  Future<dynamic> call(String method,String path,[Map<String,dynamic>? body,String? key])async{
    final h={'Content-Type':'application/json',if(token!=null)'Authorization':'Bearer $token',if(key!=null)'Idempotency-Key':key};
    final u=Uri.parse(apiBase+path);
    try{
      late http.Response r;
      if(method=='GET')r=await http.get(u,headers:h).timeout(const Duration(seconds:15));
      else if(method=='POST')r=await http.post(u,headers:h,body:jsonEncode(body??{})).timeout(const Duration(seconds:15));
      else if(method=='PATCH')r=await http.patch(u,headers:h,body:jsonEncode(body??{})).timeout(const Duration(seconds:15));
       else r=await http.delete(u,headers:h).timeout(const Duration(seconds:15));
      if(r.statusCode==401 && refreshToken!=null && !path.startsWith('/auth/')){
        final ok=await refresh();
        if(ok)return await call(method,path,body,key);
      }
      if(r.statusCode>=400){
        String message='حدث خطأ في الاتصال';
        try{final d=jsonDecode(r.body);message=(d['message']??message).toString();}catch(_){}
        throw Exception(message);
      }
      return r.body.isEmpty?{}:jsonDecode(r.body);
    }on TimeoutException{throw Exception('الاتصال بالخادم استغرق وقتًا طويلًا');}
  }
  Future<bool> refresh()async{
    try{
      final r=await post('/auth/refresh',{'refreshToken':refreshToken});
      token=r['accessToken'];refreshToken=r['refreshToken'];
      return true;
    }catch(_){token=null;refreshToken=null;return false;}
  }
  Future<dynamic> get(String p)=>call('GET',p);
  Future<dynamic> post(String p,Map<String,dynamic> b,{String? key})=>call('POST',p,b,key);
  Future<dynamic> patch(String p,Map<String,dynamic> b)=>call('PATCH',p,b);
}
class Line{final Map<String,dynamic> p;int qty;Line(this.p,[this.qty=1]);double get total=>(p['price'] as num).toDouble()*qty;}
void main()=>runApp(const App());
class App extends StatefulWidget{const App({super.key});@override State<App> createState()=>_AppState();}
class _AppState extends State<App>{
  final api=Api();final cart=<Line>[];String village='الديسمي';bool ready=false;
  @override void initState(){super.initState();_restore();}
  Future<void> _restore()async{
    final p=await SharedPreferences.getInstance();
    api.token=p.getString('accessToken');api.refreshToken=p.getString('refreshToken');api.userId=p.getString('userId');
    if(api.token!=null && api.refreshToken!=null){final ok=await api.refresh();if(ok){await _save();}else{await p.remove('accessToken');await p.remove('refreshToken');}}
    if(mounted)setState(()=>ready=true);
  }
  Future<void> _save()async{final p=await SharedPreferences.getInstance();if(api.token!=null)await p.setString('accessToken',api.token!);if(api.refreshToken!=null)await p.setString('refreshToken',api.refreshToken!);if(api.userId!=null)await p.setString('userId',api.userId!);}
  Future<void> _logout()async{final p=await SharedPreferences.getInstance();api.token=null;api.refreshToken=null;api.userId=null;await p.remove('accessToken');await p.remove('refreshToken');await p.remove('userId');if(mounted)setState((){});}
  @override Widget build(BuildContext c){
    if(!ready)return const MaterialApp(home:Scaffold(body:Center(child:CircularProgressIndicator())));
    return MaterialApp(debugShowCheckedModeBanner:false,title:'جايك',theme:ThemeData(useMaterial3:true,fontFamily:'Cairo',scaffoldBackgroundColor:cream,colorScheme:ColorScheme.fromSeed(seedColor:primary)),home:api.token==null?Login(api:api,onDone:(){_save();setState((){});}):Home(api:api,cart:cart,village:village,onVillage:(v){setState(()=>village=v);},onCart:()=>setState((){}),onLogout:_logout));
  }
}
class Login extends StatefulWidget {
  final Api api;
  final VoidCallback onDone;
  const Login({super.key, required this.api, required this.onDone});
  @override State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final phone = TextEditingController(text: '01000000004');
  final code = TextEditingController();
  String? challenge;
  bool busy = false;
  String message = '';

  Future<void> requestOtp() async {
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final result = await widget.api.post('/auth/request-otp', {'phone': phone.text.trim()});
      challenge = result['challengeId']?.toString();
      if (result['devCode'] != null) code.text = result['devCode'].toString();
      if (mounted) setState(() => message = 'تم إرسال رمز التحقق');
    } catch (e) {
      if (mounted) setState(() => message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify() async {
    if (challenge == null) { await requestOtp(); return; }
    setState(() => busy = true);
    try {
      final result = await widget.api.post('/auth/verify-otp', {
        'challengeId': challenge,
        'phone': phone.text.trim(),
        'code': code.text.trim(),
        'name': 'عميل جايك',
      });
      widget.api.token = result['accessToken'];
      widget.api.refreshToken = result['refreshToken'];
      widget.api.userId = result['user']['id'];
      widget.onDone();
    } catch (e) {
      if (mounted) setState(() => message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override void dispose() { phone.dispose(); code.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(width: 86, height: 86, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(26)), child: const Center(child: Text('ج', style: TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900)))),
                const SizedBox(height: 18),
                const Text('جايك', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: primary)),
                const Text('طلبك جايك لحد بابك', style: TextStyle(color: ink)),
                const SizedBox(height: 28),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الموبايل', prefixText: '+20 ', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رمز التحقق', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : verify, style: FilledButton.styleFrom(backgroundColor: primary), child: Text(challenge == null ? 'إرسال الرمز' : 'دخول'))),
                if (challenge != null) TextButton(onPressed: busy ? null : requestOtp, child: const Text('إرسال الرمز مرة أخرى')),
                if (message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(message)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class Home extends StatefulWidget {
  final Api api;
  final List<Line> cart;
  final String village;
  final ValueChanged<String> onVillage;
  final VoidCallback onCart;
  final VoidCallback onLogout;
  const Home({super.key, required this.api, required this.cart, required this.village, required this.onVillage, required this.onCart, required this.onLogout});
  @override State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Map<String, dynamic> data = {};
  bool loading = true;

  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final result = await widget.api.get('/home?village=${Uri.encodeComponent(widget.village)}');
      if (!mounted) return;
      setState(() { data = Map<String, dynamic>.from(result); loading = false; });
    } catch (_) {
      if (mounted) setState(() { data = {}; loading = false; });
    }
  }

  IconData icon(String value) {
    const icons = {'restaurant': Icons.restaurant, 'shopping_cart': Icons.shopping_cart, 'medication': Icons.medication, 'eco': Icons.eco, 'set_meal': Icons.set_meal, 'bakery_dining': Icons.bakery_dining};
    return icons[value] ?? Icons.storefront;
  }

  Widget sectionTitle(String value) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ink)));

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: primary)));
    final categories = List.from(data['categories'] ?? []);
    final merchants = List.from(data['merchants'] ?? []);
    final popular = List.from(data['popular'] ?? []);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: cream,
          title: const Text('جايك', style: TextStyle(color: primary, fontSize: 25, fontWeight: FontWeight.w900)),
          actions: [
            IconButton(onPressed: () => showModalBottomSheet(context: context, builder: (_) => VillagePicker(current: widget.village, onPick: (value) { widget.onVillage(value); Navigator.pop(context); load(); })), icon: const Icon(Icons.location_on_outlined, color: primary)),
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Cart(api: widget.api, cart: widget.cart, onChanged: widget.onCart))), icon: Badge(label: Text('${widget.cart.fold<int>(0, (sum, line) => sum + line.qty)}'), child: const Icon(Icons.shopping_cart_outlined, color: primary))),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('أهلاً بيك 👋', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const Text('إيه اللي جايك النهارده؟', style: TextStyle(color: ink)),
              const SizedBox(height: 14),
              TextField(onSubmitted: (query) { Navigator.push(context, MaterialPageRoute(builder: (_) => Search(api: widget.api, q: query, village: widget.village, cart: widget.cart, onChanged: widget.onCart))); }, decoration: InputDecoration(hintText: 'ابحث عن مطعم أو منتج...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
              const SizedBox(height: 18),
              sectionTitle('الخدمات'),
              GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: categories.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.1), itemBuilder: (_, index) { final item = categories[index]; return InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MerchantList(api: widget.api, village: widget.village, cart: widget.cart, onChanged: widget.onCart))), child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon('${item['icon']}'), color: primary, size: 29), const SizedBox(height: 6), Text('${item['name']}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))]))); }),
              const SizedBox(height: 18),
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(22)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('طلبك جايك.', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), SizedBox(height: 6), Text('كل اللي محتاجه... جايك لحد بابك.', style: TextStyle(color: Colors.white70))])),
              const SizedBox(height: 18),
              sectionTitle('محلات قريبة'),
              ...merchants.take(6).map((item) => MerchantTile(m: item, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Merchant(api: widget.api, id: item['id'].toString(), cart: widget.cart, onChanged: widget.onCart))))),
              const SizedBox(height: 10),
              sectionTitle('الأكثر طلبًا'),
              ...popular.map((item) => ProductTile(p: Map<String, dynamic>.from(item), onAdd: () { widget.cart.add(Line(Map<String, dynamic>.from(item))); widget.onCart(); })),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(selectedIndex: 0, onDestinationSelected: (index) {
          if (index == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => Orders(api: widget.api)));
          if (index == 2) Navigator.push(context, MaterialPageRoute(builder: (_) => Notifications(api: widget.api)));
          if (index == 3) Navigator.push(context, MaterialPageRoute(builder: (_) => Profile(api: widget.api, onLogout: widget.onLogout)));
        }, destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'طلباتي'),
          NavigationDestination(icon: Icon(Icons.notifications_none), label: 'الإشعارات'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'حسابي'),
        ]),
      ),
    );
  }
}
class VillagePicker extends StatelessWidget{final String current;final ValueChanged<String> onPick;const VillagePicker({super.key,required this.current,required this.onPick});@override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:Padding(padding:const EdgeInsets.all(18),child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('اختار منطقتك',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),for(final v in ['الديسمي','الصف','القرى المجاورة'])ListTile(title:Text(v),leading:Icon(v==current?Icons.radio_button_checked:Icons.radio_button_off,color:primary),onTap:()=>onPick(v))]))));}
class MerchantTile extends StatelessWidget{final Map m;final VoidCallback onTap;const MerchantTile({super.key,required this.m,required this.onTap});@override Widget build(BuildContext c)=>Card(elevation:0,child:ListTile(onTap:onTap,leading:CircleAvatar(backgroundColor:secondary.withOpacity(.18),child:const Icon(Icons.storefront,color:primary)),title:Text('${m['name']}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('⭐ ${m['rating']??'—'}  •  ${m['delivery_minutes']??'—'} دقيقة  •  ${m['delivery_fee']??0} ج.م'),trailing:const Icon(Icons.chevron_left)));}
class ProductTile extends StatelessWidget{final Map<String,dynamic> p;final VoidCallback onAdd;const ProductTile({super.key,required this.p,required this.onAdd});@override Widget build(BuildContext c)=>Card(elevation:0,child:ListTile(leading:Container(width:58,height:58,decoration:BoxDecoration(color:secondary.withOpacity(.15),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.fastfood,color:primary)),title:Text('${p['name']}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${p['price']} ج.م'),trailing:FilledButton(onPressed:onAdd,style:FilledButton.styleFrom(backgroundColor:primary),child:const Text('أضف'))));}
class Merchant extends StatefulWidget{final Api api;final String id;final List<Line> cart;final VoidCallback onChanged;const Merchant({super.key,required this.api,required this.id,required this.cart,required this.onChanged});@override State<Merchant> createState()=>_MerchantState();}
class _MerchantState extends State<Merchant>{Map d={};@override void initState(){super.initState();load();}Future<void> load()async{try{d=Map<String,dynamic>.from(await widget.api.get('/merchants/${widget.id}'));setState((){});}catch(_){}}@override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:Text(d['name']??'المتجر')),body:ListView(padding:const EdgeInsets.all(16),children:[if(d.isNotEmpty)Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:primary,borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${d['name']}',style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900)),Text('⭐ ${d['rating']}  •  ${d['delivery_minutes']} دقيقة',style:const TextStyle(color:Colors.white70))])),const SizedBox(height:16),...List.from(d['products']??[]).map((p)=>ProductTile(p:Map<String,dynamic>.from(p),onAdd:(){widget.cart.add(Line(Map<String,dynamic>.from(p)));widget.onChanged();ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('اتضاف للسلة')));} ))])));}
class MerchantList extends StatefulWidget{final Api api;final String village;final List<Line> cart;final VoidCallback onChanged;const MerchantList({super.key,required this.api,required this.village,required this.cart,required this.onChanged});@override State<MerchantList> createState()=>_MerchantListState();}class _MerchantListState extends State<MerchantList>{List d=[];@override void initState(){super.initState();load();}Future<void> load()async{try{d=List.from(await widget.api.get('/merchants?village=${Uri.encodeComponent(widget.village)}'));}catch(_){ }setState((){});}@override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('المحلات القريبة')),body:ListView(padding:const EdgeInsets.all(12),children:[...d.map((m)=>MerchantTile(m:m,onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Merchant(api:widget.api,id:m['id'],cart:widget.cart,onChanged:widget.onChanged)))))]));}
class Search extends StatefulWidget{final Api api;final String q,village;final List<Line> cart;final VoidCallback onChanged;const Search({super.key,required this.api,required this.q,required this.village,required this.cart,required this.onChanged});@override State<Search> createState()=>_SearchState();}class _SearchState extends State<Search>{Map d={};@override void initState(){super.initState();load();}Future<void> load()async{try{d=Map<String,dynamic>.from(await widget.api.get('/search?q=${Uri.encodeQueryComponent(widget.q)}&village=${Uri.encodeQueryComponent(widget.village)}'));}catch(_){ }setState((){});}@override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:Text('نتائج: ${widget.q}')),body:ListView(padding:const EdgeInsets.all(12),children:[const Text('المحلات',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),...List.from(d['merchants']??[]).map((m)=>MerchantTile(m:m,onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Merchant(api:widget.api,id:m['id'],cart:widget.cart,onChanged:widget.onChanged))))),const SizedBox(height:10),const Text('المنتجات',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),...List.from(d['products']??[]).map((p)=>ProductTile(p:Map<String,dynamic>.from(p),onAdd:(){widget.cart.add(Line(Map<String,dynamic>.from(p)));widget.onChanged();}))])));}
class Cart extends StatefulWidget{final Api api;final List<Line> cart;final VoidCallback onChanged;const Cart({super.key,required this.api,required this.cart,required this.onChanged});@override State<Cart> createState()=>_CartState();}
class _CartState extends State<Cart>{String? addressId,coupon;List addresses=[];double? discount;String couponMsg='';@override void initState(){super.initState();loadAddresses();}Future<void> loadAddresses()async{try{addresses=List.from(await widget.api.get('/addresses'));if(addresses.isNotEmpty)addressId=addresses.first['id'];setState((){});}catch(_){}}Future<void> validateCoupon()async{if(coupon==null||coupon!.trim().isEmpty)return;final subtotal=widget.cart.fold<double>(0,(s,x)=>s+x.total);try{final r=await widget.api.get('/coupons/validate?code=${Uri.encodeQueryComponent(coupon!.trim())}&subtotal=$subtotal');discount=(r['discount'] as num).toDouble();couponMsg='خصم ${discount!.toStringAsFixed(0)} جنيه';setState((){});}catch(_){discount=null;setState(()=>couponMsg='الكوبون غير صالح');}}Future<void> checkout()async{if(widget.cart.isEmpty)return;if(addressId==null&&addresses.isNotEmpty)addressId=addresses.first['id'];try{final merchantId=widget.cart.first.p['merchant_id'];final items=widget.cart.map((x)=>{'productId':x.p['id'],'quantity':x.qty}).toList();final body={'merchantId':merchantId,'items':items,if(addressId!=null)'addressId':addressId,if(coupon!=null&&coupon!.trim().isNotEmpty)'couponCode':coupon!.trim()};final r=await widget.api.post('/orders',body,key:'jayek-${DateTime.now().microsecondsSinceEpoch}');widget.cart.clear();widget.onChanged();if(!mounted)return;Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>Tracking(api:widget.api,orderId:r['id'])));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذر إنشاء الطلب — راجع العنوان أو الكوبون')));}}@override Widget build(BuildContext c){final subtotal=widget.cart.fold<double>(0,(s,x)=>s+x.total);final shown=(subtotal-(discount??0)).clamp(0,double.infinity);return Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('السلة')),body:ListView(padding:const EdgeInsets.all(16),children:[if(widget.cart.isEmpty)const Padding(padding:EdgeInsets.all(40),child:Center(child:Text('السلة فاضية'))),...widget.cart.map((x)=>Card(child:ListTile(title:Text('${x.p['name']}'),subtitle:Text('${x.total.toStringAsFixed(0)} ج.م'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:()=>setState(()=>x.qty++),icon:const Icon(Icons.add_circle_outline)),Text('${x.qty}'),IconButton(onPressed:()=>setState((){if(x.qty>1)x.qty--;else widget.cart.remove(x);}),icon:const Icon(Icons.remove_circle_outline))]))),if(addresses.isNotEmpty)DropdownButtonFormField<String>(value:addressId,decoration:const InputDecoration(labelText:'عنوان التوصيل',border:OutlineInputBorder()),items:addresses.map((a)=>DropdownMenuItem<String>(value:a['id'],child:Text('${a['label']} — ${a['village']}'))).toList(),onChanged:(v)=>setState(()=>addressId=v)),const SizedBox(height:12),Row(children:[Expanded(child:TextField(onChanged:(v)=>coupon=v,decoration:const InputDecoration(labelText:'كود الخصم',border:OutlineInputBorder()))),const SizedBox(width:8),FilledButton(onPressed:validateCoupon,style:FilledButton.styleFrom(backgroundColor:accent),child:const Text('تطبيق'))]),if(couponMsg.isNotEmpty)Padding(padding:const EdgeInsets.only(top:6),child:Text(couponMsg,style:const TextStyle(color:primary,fontWeight:FontWeight.w700))),const SizedBox(height:16),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('الإجمالي',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[if(discount!=null)Text('قبل الخصم ${subtotal.toStringAsFixed(0)} ج.م',style:const TextStyle(decoration:TextDecoration.lineThrough)),Text('${shown.toStringAsFixed(0)} ج.م',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:primary))])]),const SizedBox(height:16),SizedBox(height:52,width:double.infinity,child:FilledButton(onPressed:widget.cart.isEmpty?null:checkout,style:FilledButton.styleFrom(backgroundColor:primary),child:const Text('تأكيد الطلب — الدفع عند الاستلام')))]));}}

class Orders extends StatefulWidget{final Api api;const Orders({super.key,required this.api});@override State<Orders> createState()=>_OrdersState();}class _OrdersState extends State<Orders>{List d=[];@override void initState(){super.initState();load();}Future<void> load()async{try{d=List.from(await widget.api.get('/orders'));setState((){});}catch(_){}}String ar(String s)=>{'CREATED':'جديد','CONFIRMED':'مؤكد','ACCEPTED_BY_MERCHANT':'المتجر قبل الطلب','PREPARING':'جاري التحضير','READY_FOR_PICKUP':'جاهز للاستلام','ASSIGNED_RIDER':'تم تعيين كابتن','PICKED_UP':'استلم الكابتن الطلب','ON_THE_WAY':'في الطريق','DELIVERED':'تم التسليم','CANCELLED':'ملغي'}[s]??s;@override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('طلباتي')),body:RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(12),children:[...d.map((o)=>Card(child:ListTile(onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Tracking(api:widget.api,orderId:o['id']))),title:Text('${o['merchant_name']}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${ar(o['status'])}\n${o['total']} ج.م'),isThreeLine:true,trailing:PopupMenuButton<String>(onSelected:(v){if(v=='reorder')Navigator.push(c,MaterialPageRoute(builder:(_)=>Reorder(api:widget.api,orderId:o['id'])));if(v=='review')Navigator.push(c,MaterialPageRoute(builder:(_)=>Review(api:widget.api,orderId:o['id'])));},itemBuilder:(_)=>[const PopupMenuItem(value:'reorder',child:Text('إعادة الطلب')),if(o['status']=='DELIVERED')const PopupMenuItem(value:'review',child:Text('قيّم الطلب'))])))]))));)}
class Tracking extends StatefulWidget{final Api api;final String orderId;const Tracking({super.key,required this.api,required this.orderId});@override State<Tracking> createState()=>_TrackingState();}class _TrackingState extends State<Tracking>{Map d={};@override void initState(){super.initState();load();}Future<void> load()async{try{d=Map<String,dynamic>.from(await widget.api.get('/tracking/${widget.orderId}'));setState((){});}catch(_){}}String ar(String s)=>{'CREATED':'تم إنشاء الطلب','CONFIRMED':'تم تأكيد الطلب','ACCEPTED_BY_MERCHANT':'المتجر قبل الطلب','PREPARING':'جاري التحضير','READY_FOR_PICKUP':'جاهز للكابتن','ASSIGNED_RIDER':'تم تعيين الكابتن','PICKED_UP':'الكابتن استلم الطلب','ON_THE_WAY':'الطلب في الطريق','DELIVERED':'تم التسليم'}[s]??s;@override Widget build(BuildContext c){final h=List.from(d['history']??[]);return Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('تتبع الطلب')),body:RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(18),children:[Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:primary,borderRadius:BorderRadius.circular(22)),child:Column(children:[const Icon(Icons.delivery_dining,color:Colors.white,size:54),const SizedBox(height:8),Text(ar('${d['status']??'CREATED'}'),style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),if(d['rider']!=null)const Text('الكابتن متابع الطلب معاك',style:TextStyle(color:Colors.white70))])),const SizedBox(height:18),const Text('مراحل الطلب',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),...h.map((x)=>ListTile(leading:const Icon(Icons.check_circle,color:primary),title:Text(ar('${x['status']}')),subtitle:Text('${x['created_at']??''}')))])));)}}
class Notifications extends StatefulWidget{final Api api;const Notifications({super.key,required this.api});@override State<Notifications> createState()=>_NotificationsState();}class _NotificationsState extends State<Notifications>{List d=[];@override void initState(){super.initState();load();}Future<void> load()async{try{d=List.from(await widget.api.get('/notifications'));setState((){});}catch(_){}}@override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('الإشعارات')),body:ListView(padding:const EdgeInsets.all(12),children:[...d.map((n)=>Card(child:ListTile(onTap:()=>widget.api.patch('/notifications/${n['id']}/read',{}),leading:const Icon(Icons.notifications_active,color:accent),title:Text('${n['title']}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${n['body']}'))))]));)}}
class Profile extends StatelessWidget{final Api api;final VoidCallback onLogout;const Profile({super.key,required this.api,required this.onLogout});@override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('حسابي')),body:ListView(padding:const EdgeInsets.all(16),children:[Card(child:ListTile(leading:const CircleAvatar(backgroundColor:primary,child:Icon(Icons.person,color:Colors.white)),title:const Text('حساب عميل جايك'),subtitle:Text(api.userId??''))),const SizedBox(height:10),ListTile(leading:const Icon(Icons.location_on_outlined),title:const Text('العناوين'),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Addresses(api:api)))),ListTile(leading:const Icon(Icons.favorite_border,color:accent),title:const Text('المفضلة'),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Favorites(api:api)))),ListTile(leading:const Icon(Icons.support_agent),title:const Text('الدعم والمساعدة'),onTap:()=>showDialog(context:c,builder:(_)=>SupportDialog(api:api))),const SizedBox(height:20),OutlinedButton.icon(onPressed:onLogout,icon:const Icon(Icons.logout),label:const Text('تسجيل الخروج'))]));)}}
class Addresses extends StatefulWidget{final Api api;const Addresses({super.key,required this.api});@override State<Addresses> createState()=>_AddressesState();}class _AddressesState extends State<Addresses>{List d=[];@override void initState(){super.initState();load();}Future<void> load()async{try{d=List.from(await widget.api.get('/addresses'));setState((){});}catch(_){}}@override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('عناويني')),body:ListView(padding:const EdgeInsets.all(12),children:[...d.map((a)=>Card(child:ListTile(leading:const Icon(Icons.home,color:primary),title:Text('${a['label']}'),subtitle:Text('${a['village']} — ${a['details']??''}'))))]));)}}
class SupportDialog extends StatefulWidget{final Api api;const SupportDialog({super.key,required this.api});@override State<SupportDialog> createState()=>_SupportDialogState();}class _SupportDialogState extends State<SupportDialog>{final s=TextEditingController(),m=TextEditingController();bool busy=false;@override Widget build(BuildContext c)=>AlertDialog(title:const Text('الدعم'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:s,decoration:const InputDecoration(labelText:'الموضوع')),TextField(controller:m,decoration:const InputDecoration(labelText:'الرسالة'),maxLines:4)]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),FilledButton(onPressed:busy?null:()async{setState(()=>busy=true);try{await widget.api.post('/support/tickets',{'subject':s.text,'message':m.text});if(c.mounted)Navigator.pop(c);}catch(_){}} ,child:const Text('إرسال'))]);}}

class Favorites extends StatefulWidget{final Api api;const Favorites({super.key,required this.api});@override State<Favorites> createState()=>_FavoritesState();}
class _FavoritesState extends State<Favorites>{List d=[];@override void initState(){super.initState();load();}Future<void> load()async{try{d=List.from(await widget.api.get('/favorites'));setState((){});}catch(_){}}@override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('المفضلة')),body:RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(12),children:[if(d.isEmpty)const Padding(padding:EdgeInsets.all(30),child:Center(child:Text('لسه مفيش متاجر في المفضلة'))),...d.map((m)=>MerchantTile(m:m,onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Merchant(api:widget.api,id:m['id'],cart:[],onChanged:(){}))))]))));)}}
class Reorder extends StatefulWidget{final Api api;final String orderId;const Reorder({super.key,required this.api,required this.orderId});@override State<Reorder> createState()=>_ReorderState();}
class _ReorderState extends State<Reorder>{Map d={};@override void initState(){super.initState();load();}Future<void> load()async{try{d=Map<String,dynamic>.from(await widget.api.post('/orders/${widget.orderId}/reorder',{}));setState((){});}catch(_){}}@override Widget build(BuildContext c){final items=List.from(d['items']??[]);return Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('إعادة الطلب')),body:ListView(padding:const EdgeInsets.all(16),children:[const Text('راجع الأصناف ثم أضفها للسلة من المتجر.',style:TextStyle(fontSize:16)),const SizedBox(height:12),...items.map((x)=>ListTile(leading:const Icon(Icons.fastfood,color:primary),title:Text('منتج ${x['product_id']}'),trailing:Text('× ${x['quantity']}'))),const SizedBox(height:12),FilledButton(onPressed:items.isEmpty?null:()=>ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('إعادة الطلب محفوظة — افتح المتجر لإضافة الأصناف المتاحة'))),style:FilledButton.styleFrom(backgroundColor:primary),child:const Text('متابعة'))]));)}}
class Review extends StatefulWidget{final Api api;final String orderId;const Review({super.key,required this.api,required this.orderId});@override State<Review> createState()=>_ReviewState();}
class _ReviewState extends State<Review>{int rating=5;final comment=TextEditingController();bool busy=false;Future<void> submit()async{setState(()=>busy=true);try{await widget.api.post('/reviews',{'orderId':widget.orderId,'rating':rating,'comment':comment.text.trim()});if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('شكرًا لتقييمك ❤️')));Navigator.pop(context);}}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('لا يمكن تقييم الطلب حاليًا')));}finally{if(mounted)setState(()=>busy=false);}}@override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('قيّم تجربتك')),body:ListView(padding:const EdgeInsets.all(22),children:[const Text('تقييمك بيساعدنا نطوّر جايك',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:20),Row(mainAxisAlignment:MainAxisAlignment.center,children:[for(int i=1;i<=5;i++)IconButton(onPressed:()=>setState(()=>rating=i),icon:Icon(i<=rating?Icons.star:Icons.star_border,color:accent,size:40))]),TextField(controller:comment,maxLines:4,decoration:const InputDecoration(labelText:'ملاحظاتك (اختياري)',border:OutlineInputBorder())),const SizedBox(height:18),SizedBox(height:52,child:FilledButton(onPressed:busy?null:submit,style:FilledButton.styleFrom(backgroundColor:primary),child:const Text('إرسال التقييم')))]));)}}
