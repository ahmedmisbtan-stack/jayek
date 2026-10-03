import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

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
      if(method=='GET'){r=await http.get(u,headers:h).timeout(const Duration(seconds:15));}
      else if(method=='POST'){r=await http.post(u,headers:h,body:jsonEncode(body??{})).timeout(const Duration(seconds:15));}
      else if(method=='PATCH'){r=await http.patch(u,headers:h,body:jsonEncode(body??{})).timeout(const Duration(seconds:15));}
       else {r=await http.delete(u,headers:h).timeout(const Duration(seconds:15));}
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
bool addProductToCart(BuildContext context, List<Line> cart, Map<String,dynamic> product, VoidCallback onChanged){
  final merchantId=product['merchant_id']?.toString();
  if(merchantId==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('بيانات المتجر غير صالحة')));return false;}
  if(cart.isNotEmpty && cart.first.p['merchant_id']?.toString()!=merchantId){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('السلة لمتجر واحد فقط. فضّي السلة الأول لو عايز تطلب من متجر تاني.')));return false;}
  final existing=cart.where((x)=>x.p['id']?.toString()==product['id']?.toString()).toList();
  if(existing.isNotEmpty){existing.first.qty++;}else{cart.add(Line(Map<String,dynamic>.from(product)));}
  onChanged(); return true;
}

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
              ...popular.map((item) => ProductTile(p: Map<String, dynamic>.from(item), onAdd: () { addProductToCart(context, widget.cart, Map<String,dynamic>.from(item), widget.onCart); })),
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
class MerchantTile extends StatelessWidget{final Map m;final VoidCallback onTap;const MerchantTile({super.key,required this.m,required this.onTap});@override Widget build(BuildContext c)=>Card(elevation:0,child:ListTile(onTap:onTap,leading:CircleAvatar(backgroundColor:secondary.withValues(alpha:.18),child:const Icon(Icons.storefront,color:primary)),title:Text('${m['name']}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('⭐ ${m['rating']??'—'}  •  ${m['delivery_minutes']??'—'} دقيقة  •  ${m['delivery_fee']??0} ج.م'),trailing:const Icon(Icons.chevron_left)));}
class ProductTile extends StatelessWidget{final Map<String,dynamic> p;final VoidCallback onAdd;const ProductTile({super.key,required this.p,required this.onAdd});@override Widget build(BuildContext c)=>Card(elevation:0,child:ListTile(leading:Container(width:58,height:58,decoration:BoxDecoration(color:secondary.withValues(alpha:.15),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.fastfood,color:primary)),title:Text('${p['name']}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${p['price']} ج.م'),trailing:FilledButton(onPressed:onAdd,style:FilledButton.styleFrom(backgroundColor:primary),child:const Text('أضف'))));}
class Merchant extends StatefulWidget{final Api api;final String id;final List<Line> cart;final VoidCallback onChanged;const Merchant({super.key,required this.api,required this.id,required this.cart,required this.onChanged});@override State<Merchant> createState()=>_MerchantState();}
class _MerchantState extends State<Merchant>{Map d={};@override void initState(){super.initState();load();}Future<void> load()async{try{d=Map<String,dynamic>.from(await widget.api.get('/merchants/${widget.id}'));setState((){});}catch(_){}}@override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:Text(d['name']??'المتجر')),body:ListView(padding:const EdgeInsets.all(16),children:[if(d.isNotEmpty)Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:primary,borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${d['name']}',style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900)),Text('⭐ ${d['rating']}  •  ${d['delivery_minutes']} دقيقة',style:const TextStyle(color:Colors.white70))])),const SizedBox(height:16),...List.from(d['products']??[]).map((p)=>ProductTile(p:Map<String,dynamic>.from(p),onAdd:(){widget.cart.add(Line(Map<String,dynamic>.from(p)));widget.onChanged();ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('اتضاف للسلة')));} ))])));}
class MerchantList extends StatefulWidget {
  final Api api; final String village; final List<Line> cart; final VoidCallback onChanged;
  const MerchantList({super.key, required this.api, required this.village, required this.cart, required this.onChanged});
  @override State<MerchantList> createState() => _MerchantListState();
}
class _MerchantListState extends State<MerchantList> {
  List<dynamic> merchants = [];
  bool loading = true;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final value = await widget.api.get('/merchants?village=${Uri.encodeComponent(widget.village)}');
      merchants = List<dynamic>.from(value as List);
    } catch (_) { merchants = []; }
    if (mounted) setState(() => loading = false);
  }
  @override Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('المحلات القريبة')),
      body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          if (merchants.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('مفيش محلات متاحة حاليًا'))),
          ...merchants.map((m) => MerchantTile(
            m: Map<String, dynamic>.from(m as Map),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Merchant(api: widget.api, id: m['id'].toString(), cart: widget.cart, onChanged: widget.onChanged))),
          )),
        ]),
      ),
    ));
  }
}

class Search extends StatefulWidget {
  final Api api; final String q; final String village; final List<Line> cart; final VoidCallback onChanged;
  const Search({super.key, required this.api, required this.q, required this.village, required this.cart, required this.onChanged});
  @override State<Search> createState() => _SearchState();
}
class _SearchState extends State<Search> {
  Map<String, dynamic> data = {};
  bool loading = true;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final value = await widget.api.get('/search?q=${Uri.encodeQueryComponent(widget.q)}&village=${Uri.encodeQueryComponent(widget.village)}');
      data = Map<String, dynamic>.from(value as Map);
    } catch (_) { data = {}; }
    if (mounted) setState(() => loading = false);
  }
  @override Widget build(BuildContext context) {
    final merchants = List<dynamic>.from(data['merchants'] ?? const []);
    final products = List<dynamic>.from(data['products'] ?? const []);
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: Text('نتائج: ${widget.q}')),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(12), children: [
        const Text('المحلات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ...merchants.map((m) => MerchantTile(m: Map<String, dynamic>.from(m as Map), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Merchant(api: widget.api, id: m['id'].toString(), cart: widget.cart, onChanged: widget.onChanged))))),
        const SizedBox(height: 10),
        const Text('المنتجات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ...products.map((p) => ProductTile(p: Map<String, dynamic>.from(p), onAdd: () { addProductToCart(context, widget.cart, Map<String,dynamic>.from(p as Map), widget.onChanged); })),
      ]),
    ));
  }
}

class Cart extends StatefulWidget {
  final Api api; final List<Line> cart; final VoidCallback onChanged;
  const Cart({super.key, required this.api, required this.cart, required this.onChanged});
  @override State<Cart> createState() => _CartState();
}
class _CartState extends State<Cart> {
  String? addressId; String coupon = ''; List<dynamic> addresses = []; double? discount; String couponMsg = ''; bool busy = false;
  @override void initState() { super.initState(); loadAddresses(); }
  Future<void> loadAddresses() async {
    try {
      addresses = List<dynamic>.from(await widget.api.get('/addresses') as List);
      if (addresses.isNotEmpty) addressId = addresses.first['id'].toString();
    } catch (_) { addresses = []; }
    if (mounted) setState(() {});
  }
  double get subtotal => widget.cart.fold<double>(0, (sum, line) => sum + line.total);
  Future<void> validateCoupon() async {
    if (coupon.trim().isEmpty) return;
    try {
      final result = await widget.api.get('/coupons/validate?code=${Uri.encodeQueryComponent(coupon.trim())}&subtotal=$subtotal');
      discount = (result['discount'] as num? ?? 0).toDouble();
      couponMsg = 'خصم ${discount!.toStringAsFixed(0)} جنيه';
    } catch (_) { discount = null; couponMsg = 'الكوبون غير صالح'; }
    if (mounted) setState(() {});
  }
  Future<void> checkout() async {
    if (busy || widget.cart.isEmpty) return;
    final merchantId = widget.cart.first.p['merchant_id']?.toString();
    if (merchantId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بيانات المتجر غير صالحة'))); return; }
    if (addressId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف عنوان توصيل أولًا'))); return; }
    setState(() => busy = true);
    try {
      final items = widget.cart.map((x) => {'productId': x.p['id'], 'quantity': x.qty}).toList();
      final body = <String, dynamic>{'merchantId': merchantId, 'items': items, 'addressId': addressId, if (coupon.trim().isNotEmpty) 'couponCode': coupon.trim()};
      final result = await widget.api.post('/orders', body, key: 'jayek-${DateTime.now().microsecondsSinceEpoch}');
      widget.cart.clear(); widget.onChanged();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Tracking(api: widget.api, orderId: result['id'].toString())));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) {
    final shown = (subtotal - (discount ?? 0)).clamp(0, double.infinity);
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('السلة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (widget.cart.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('السلة فاضية'))),
        ...widget.cart.map((line) => Card(child: ListTile(
          title: Text('${line.p['name']}'), subtitle: Text('${line.total.toStringAsFixed(0)} ج.م'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(onPressed: () => setState(() => line.qty++), icon: const Icon(Icons.add_circle_outline)),
            Text('${line.qty}'),
            IconButton(onPressed: () => setState(() { if (line.qty > 1) { line.qty--; } else { widget.cart.remove(line); } widget.onChanged(); }), icon: const Icon(Icons.remove_circle_outline)),
          ]),
        ))),
        if (addresses.isNotEmpty) DropdownButtonFormField<String>(
          initialValue: addressId,
          decoration: const InputDecoration(labelText: 'عنوان التوصيل', border: OutlineInputBorder()),
          items: addresses.map((a) => DropdownMenuItem<String>(value: a['id'].toString(), child: Text('${a['label'] ?? 'عنوان'} — ${a['village']}'))).toList(),
          onChanged: (value) => setState(() => addressId = value),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(onChanged: (value) => coupon = value, decoration: const InputDecoration(labelText: 'كود الخصم', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          FilledButton(onPressed: validateCoupon, style: FilledButton.styleFrom(backgroundColor: accent), child: const Text('تطبيق')),
        ]),
        if (couponMsg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(couponMsg, style: const TextStyle(color: primary, fontWeight: FontWeight.w700))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('المنتجات بعد الخصم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          Text('${shown.toStringAsFixed(0)} ج.م + رسوم التوصيل', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primary)),
        ]),
        const SizedBox(height: 16),
        SizedBox(height: 52, width: double.infinity, child: FilledButton(onPressed: widget.cart.isEmpty || busy ? null : checkout, style: FilledButton.styleFrom(backgroundColor: primary), child: Text(busy ? 'جاري إنشاء الطلب...' : 'تأكيد الطلب — الدفع عند الاستلام'))),
      ]),
    ));
  }
}

class Orders extends StatefulWidget {
  final Api api; const Orders({super.key, required this.api});
  @override State<Orders> createState() => _OrdersState();
}
class _OrdersState extends State<Orders> {
  List<dynamic> orders = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { try { orders = List<dynamic>.from(await widget.api.get('/orders') as List); } catch (_) { orders = []; } if (mounted) setState(() {}); }
  String statusText(String value) => {'CREATED':'جديد','CONFIRMED':'مؤكد','ACCEPTED_BY_MERCHANT':'المتجر قبل الطلب','PREPARING':'جاري التحضير','READY_FOR_PICKUP':'جاهز للاستلام','ASSIGNED_RIDER':'تم تعيين كابتن','PICKED_UP':'استلم الكابتن الطلب','ON_THE_WAY':'في الطريق','DELIVERED':'تم التسليم','CANCELLED':'ملغي','REJECTED':'مرفوض'}[value] ?? value;
  @override Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('طلباتي')),
    body: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(12), children: [
      if (orders.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('لسه مفيش طلبات'))),
      ...orders.map((order) => Card(child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Tracking(api: widget.api, orderId: order['id'].toString()))),
        title: Text('${order['merchant_name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${statusText('${order['status']}')}\n${order['total']} ج.م'), isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'reorder') Navigator.push(context, MaterialPageRoute(builder: (_) => Reorder(api: widget.api, orderId: order['id'].toString())));
            if (value == 'review') Navigator.push(context, MaterialPageRoute(builder: (_) => Review(api: widget.api, orderId: order['id'].toString())));
          },
          itemBuilder: (_) => [const PopupMenuItem(value: 'reorder', child: Text('إعادة الطلب')), if (order['status'] == 'DELIVERED') const PopupMenuItem(value: 'review', child: Text('قيّم الطلب'))],
        ),
      ))),
    ])),
  ));
}

class Tracking extends StatefulWidget {
  final Api api; final String orderId;
  const Tracking({super.key, required this.api, required this.orderId});
  @override State<Tracking> createState() => _TrackingState();
}
class _TrackingState extends State<Tracking> {
  Map<String, dynamic> data = {};
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { try { data = Map<String, dynamic>.from(await widget.api.get('/tracking/${widget.orderId}') as Map); } catch (_) { data = {}; } if (mounted) setState(() {}); }
  String statusText(String value) => {'CREATED':'تم إنشاء الطلب','CONFIRMED':'تم تأكيد الطلب','ACCEPTED_BY_MERCHANT':'المتجر قبل الطلب','PREPARING':'جاري التحضير','READY_FOR_PICKUP':'جاهز للكابتن','ASSIGNED_RIDER':'تم تعيين الكابتن','PICKED_UP':'الكابتن استلم الطلب','ON_THE_WAY':'الطلب في الطريق','DELIVERED':'تم التسليم','CANCELLED':'تم الإلغاء','REJECTED':'تم الرفض'}[value] ?? value;
  @override Widget build(BuildContext context) {
    final history = List<dynamic>.from(data['history'] ?? const []);
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('تتبع الطلب')),
      body: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(18), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(22)), child: Column(children: [
          const Icon(Icons.delivery_dining, color: Colors.white, size: 54), const SizedBox(height: 8),
          Text(statusText('${data['status'] ?? 'CREATED'}'), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        ])),
        const SizedBox(height: 18), const Text('مراحل الطلب', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        ...history.map((item) => ListTile(leading: const Icon(Icons.check_circle, color: primary), title: Text(statusText('${item['status']}')), subtitle: Text('${item['created_at'] ?? ''}'))),
      ])),
    ));
  }
}

class Notifications extends StatefulWidget {
  final Api api; const Notifications({super.key, required this.api});
  @override State<Notifications> createState() => _NotificationsState();
}
class _NotificationsState extends State<Notifications> {
  List<dynamic> notifications = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { try { notifications = List<dynamic>.from(await widget.api.get('/notifications') as List); } catch (_) { notifications = []; } if (mounted) setState(() {}); }
  @override Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('الإشعارات'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
    body: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(12), children: [
      if (notifications.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('مفيش إشعارات جديدة'))),
      ...notifications.map((n) => Card(child: ListTile(onTap: () async { await widget.api.patch('/notifications/${n['id']}/read', {}); await load(); }, leading: const Icon(Icons.notifications_active, color: accent), title: Text('${n['title']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${n['body']}')))),
    ])),
  ));
}

class Profile extends StatelessWidget {
  final Api api; final VoidCallback onLogout;
  const Profile({super.key, required this.api, required this.onLogout});
  @override Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('حسابي')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(leading: const CircleAvatar(backgroundColor: primary, child: Icon(Icons.person, color: Colors.white)), title: const Text('حساب عميل جايك'), subtitle: Text(api.userId ?? ''))),
      ListTile(leading: const Icon(Icons.location_on_outlined), title: const Text('العناوين'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Addresses(api: api)))),
      ListTile(leading: const Icon(Icons.favorite_border, color: accent), title: const Text('المفضلة'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Favorites(api: api)))),
      ListTile(leading: const Icon(Icons.support_agent), title: const Text('الدعم والمساعدة'), onTap: () => showDialog<void>(context: context, builder: (_) => SupportDialog(api: api))),
      const SizedBox(height: 20), OutlinedButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج')),
    ]),
  ));
}

class AddAddressDialog extends StatefulWidget{
 final Api api; const AddAddressDialog({super.key,required this.api});
 @override State<AddAddressDialog> createState()=>_AddAddressDialogState();
}
class _AddAddressDialogState extends State<AddAddressDialog>{
 final label=TextEditingController(text:'البيت'); final details=TextEditingController();
 String village='الديسمي',message=''; Position? position; bool busy=false;
 Future<void> locate() async{try{setState(()=>busy=true);if(!await Geolocator.isLocationServiceEnabled())throw Exception('فعّل خدمة الموقع أولًا');var p=await Geolocator.checkPermission();if(p==LocationPermission.denied)p=await Geolocator.requestPermission();if(p==LocationPermission.denied||p==LocationPermission.deniedForever)throw Exception('اسمح بالموقع من إعدادات الهاتف');position=await Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,timeLimit:Duration(seconds:10)));if(mounted)setState(()=>message='تم تحديد موقعك');}catch(e){if(mounted)setState(()=>message=e.toString().replaceFirst('Exception: ',''));}finally{if(mounted)setState(()=>busy=false);}}
 Future<void> save() async{if(position==null){await locate();if(position==null)return;}try{setState(()=>busy=true);await widget.api.post('/addresses',{'label':label.text.trim().isEmpty?'البيت':label.text.trim(),'village':village,'details':details.text.trim(),'latitude':position!.latitude,'longitude':position!.longitude,'isDefault':true});if(mounted)Navigator.pop(context,true);}catch(e){if(mounted)setState(()=>message=e.toString().replaceFirst('Exception: ',''));}finally{if(mounted)setState(()=>busy=false);}}
 @override void dispose(){label.dispose();details.dispose();super.dispose();}
 @override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,child(AlertDialog(title:const Text('إضافة عنوان'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:label,decoration:const InputDecoration(labelText:'اسم العنوان')),const SizedBox(height:8),DropdownButtonFormField<String>(initialValue:village,items:const ['الديسمي','الصف','القرى المجاورة'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v!=null)setState(()=>village=v);},decoration:const InputDecoration(labelText:'القرية')),const SizedBox(height:8),TextField(controller:details,maxLines:2,decoration:const InputDecoration(labelText:'تفاصيل العنوان')),const SizedBox(height:8),OutlinedButton.icon(onPressed:busy?null:locate,icon:const Icon(Icons.my_location),label:Text(position==null?'حدد موقعي الحالي':'تحديث الموقع')),if(message.isNotEmpty)Text(message)])),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(c),child:const Text('إلغاء')),FilledButton(onPressed:busy?null:save,child:Text(busy?'جاري الحفظ...':'حفظ'))])));
}

class Addresses extends StatefulWidget {
  final Api api; const Addresses({super.key, required this.api});
  @override State<Addresses> createState() => _AddressesState();
}
class _AddressesState extends State<Addresses> {
  List<dynamic> addresses = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { try { addresses = List<dynamic>.from(await widget.api.get('/addresses') as List); } catch (_) { addresses = []; } if (mounted) setState(() {}); }
  @override Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('عناويني')), floatingActionButton: FloatingActionButton.extended(onPressed: () async {final ok=await showDialog<bool>(context:context,builder:(_)=>AddAddressDialog(api:widget.api));if(ok==true)load();},icon:const Icon(Icons.add_location_alt),label:const Text('إضافة عنوان')),
    body: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(12), children: [
      if (addresses.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('أضف عنوان توصيل باستخدام موقعك الحالي'))),
      ...addresses.map((a) => Card(child: ListTile(leading: const Icon(Icons.home, color: primary), title: Text('${a['label'] ?? 'عنوان'}'), subtitle: Text('${a['village']} — ${a['details'] ?? ''}')))),
    ])),
  ));
}

class SupportDialog extends StatefulWidget {
  final Api api; const SupportDialog({super.key, required this.api});
  @override State<SupportDialog> createState() => _SupportDialogState();
}
class _SupportDialogState extends State<SupportDialog> {
  final subject = TextEditingController(); final message = TextEditingController(); bool busy = false;
  @override void dispose() { subject.dispose(); message.dispose(); super.dispose(); }
  Future<void> send() async {
    if (busy || subject.text.trim().isEmpty || message.text.trim().isEmpty) return;
    setState(() => busy = true);
    try { await widget.api.post('/support/tickets', {'subject': subject.text.trim(), 'message': message.text.trim()}); if (mounted) Navigator.pop(context); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => AlertDialog(
    title: const Text('الدعم'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: subject, decoration: const InputDecoration(labelText: 'الموضوع')), TextField(controller: message, maxLines: 4, decoration: const InputDecoration(labelText: 'الرسالة'))]),
    actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: busy ? null : send, child: Text(busy ? 'جاري...' : 'إرسال'))],
  );
}

class Favorites extends StatefulWidget {
  final Api api; const Favorites({super.key, required this.api});
  @override State<Favorites> createState() => _FavoritesState();
}
class _FavoritesState extends State<Favorites> {
  List<dynamic> favorites = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { try { favorites = List<dynamic>.from(await widget.api.get('/favorites') as List); } catch (_) { favorites = []; } if (mounted) setState(() {}); }
  @override Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('المفضلة')),
    body: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(12), children: [
      if (favorites.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('لسه مفيش متاجر في المفضلة'))),
      ...favorites.map((m) => MerchantTile(m: Map<String, dynamic>.from(m as Map), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Merchant(api: widget.api, id: m['id'].toString(), cart: <Line>[], onChanged: () {}))))),
    ])),
  ));
}

class Reorder extends StatefulWidget {
  final Api api; final String orderId; const Reorder({super.key, required this.api, required this.orderId});
  @override State<Reorder> createState() => _ReorderState();
}
class _ReorderState extends State<Reorder> {
  Map<String, dynamic> data = {};
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { try { data = Map<String, dynamic>.from(await widget.api.post('/orders/${widget.orderId}/reorder', {}) as Map); } catch (_) { data = {}; } if (mounted) setState(() {}); }
  @override Widget build(BuildContext context) {
    final items = List<dynamic>.from(data['items'] ?? const []);
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(appBar: AppBar(title: const Text('إعادة الطلب')), body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('راجع الأصناف ثم أضف المتاح منها للسلة.'),
      ...items.map((item) => ListTile(leading: const Icon(Icons.fastfood, color: primary), title: Text('منتج ${item['product_id']}'), trailing: Text('× ${item['quantity']}'))),
    ])));
  }
}

class Review extends StatefulWidget {
  final Api api; final String orderId; const Review({super.key, required this.api, required this.orderId});
  @override State<Review> createState() => _ReviewState();
}
class _ReviewState extends State<Review> {
  int rating = 5; final comment = TextEditingController(); bool busy = false;
  @override void dispose() { comment.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (busy) return; setState(() => busy = true);
    try { await widget.api.post('/reviews', {'orderId': widget.orderId, 'rating': rating, 'comment': comment.text.trim()}); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شكرًا لتقييمك ❤️'))); Navigator.pop(context); } }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن تقييم الطلب حاليًا'))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('قيّم تجربتك')),
    body: ListView(padding: const EdgeInsets.all(22), children: [
      const Text('تقييمك بيساعدنا نطوّر جايك', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 1; i <= 5; i++) IconButton(onPressed: () => setState(() => rating = i), icon: Icon(i <= rating ? Icons.star : Icons.star_border, color: accent, size: 40))]),
      TextField(controller: comment, maxLines: 4, decoration: const InputDecoration(labelText: 'ملاحظاتك (اختياري)', border: OutlineInputBorder())),
      const SizedBox(height: 18),
      SizedBox(height: 52, child: FilledButton(onPressed: busy ? null : submit, style: FilledButton.styleFrom(backgroundColor: primary), child: const Text('إرسال التقييم'))),
    ]),
  ));
}
