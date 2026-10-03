import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const primary=Color(0xFF176B4D), accent=Color(0xFFF39A3D), cream=Color(0xFFFFF8EA);
const base=String.fromEnvironment('JAYEK_API',defaultValue:'http://10.0.2.2:3000/api/v1');
const uid=String.fromEnvironment('JAYEK_RIDER_USER',defaultValue:'');
const riderToken=String.fromEnvironment('JAYEK_RIDER_TOKEN',defaultValue:'');

class Api {
  String? token;
  Future<dynamic> call(String m,String p,[Map<String,dynamic>? b]) async {
    final h={'Content-Type':'application/json',if(token!=null)'Authorization':'Bearer $token'};
    final u=Uri.parse(base+p);
    late http.Response r;
    try{
      if(m=='GET') r=await http.get(u,headers:h).timeout(const Duration(seconds:15));
      else if(m=='POST') r=await http.post(u,headers:h,body:jsonEncode(b??{})).timeout(const Duration(seconds:15));
      else r=await http.patch(u,headers:h,body:jsonEncode(b??{})).timeout(const Duration(seconds:15));
    }on TimeoutException{throw Exception('الاتصال بالخادم استغرق وقتًا طويلًا');}
    if(r.statusCode>=400){
      String msg='حدث خطأ';
      try{final d=jsonDecode(r.body);msg=String(d['message']??msg);}catch(_){}
      throw Exception(msg);
    }
    return r.body.isEmpty?{}:jsonDecode(r.body);
  }
  Future<dynamic> get(String p)=>call('GET',p);
  Future<dynamic> post(String p,[Map<String,dynamic>? b])=>call('POST',p,b);
  Future<dynamic> patch(String p,[Map<String,dynamic>? b])=>call('PATCH',p,b);
}
void main()=>runApp(const Rider());
class Rider extends StatefulWidget{const Rider({super.key});@override State<Rider> createState()=>_RiderState();}
class _RiderState extends State<Rider>{
  final api=Api();bool ready=false;
  @override void initState(){super.initState();_restore();}
  Future<void> _restore()async{final p=await SharedPreferences.getInstance();api.token=p.getString('riderToken');if(mounted)setState(()=>ready=true);}
  Future<void> _save(String token)async{api.token=token;final p=await SharedPreferences.getInstance();await p.setString('riderToken',token);if(mounted)setState((){});}
  Future<void> _logout()async{api.token=null;final p=await SharedPreferences.getInstance();await p.remove('riderToken');if(mounted)setState((){});}
  @override Widget build(BuildContext c){if(!ready)return const MaterialApp(home:Scaffold(body:Center(child:CircularProgressIndicator())));return MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:cream,colorScheme:ColorScheme.fromSeed(seedColor:primary)),home:api.token==null?RiderLogin(api:api,onDone:_save):RiderHome(api:api,onLogout:_logout));}
}
class RiderLogin extends StatefulWidget{final Api api;final Future<void> Function(String) onDone;const RiderLogin({super.key,required this.api,required this.onDone});@override State<RiderLogin> createState()=>_RiderLoginState();}
class _RiderLoginState extends State<RiderLogin>{final phone=TextEditingController(text:'01000000003'),code=TextEditingController();String? challenge;bool busy=false;String msg='';Future<void> request()async{setState(()=>busy=true);try{final r=await widget.api.post('/auth/request-otp',{'phone':phone.text.trim()});challenge=r['challengeId'];if(r['devCode']!=null)code.text=String(r['devCode']);msg='تم إرسال الرمز';}catch(e){msg=e.toString().replaceFirst('Exception: ','');}finally{if(mounted)setState(()=>busy=false);}}Future<void> verify()async{if(challenge==null){await request();return;}setState(()=>busy=true);try{final r=await widget.api.post('/auth/verify-otp',{'challengeId':challenge,'phone':phone.text.trim(),'code':code.text.trim(),'name':'كابتن جايك'});if(r['user']?['role']!='RIDER'){throw Exception('هذا الحساب ليس حساب كابتن');}await widget.onDone(String(r['accessToken']));}catch(e){if(mounted)setState(()=>msg=e.toString().replaceFirst('Exception: ',''));}finally{if(mounted)setState(()=>busy=false);}}@override void dispose(){phone.dispose();code.dispose();super.dispose();}@override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(children:[const Icon(Icons.two_wheeler,size:76,color:primary),const Text('جايك — الكابتن',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900,color:primary)),const SizedBox(height:24),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'رقم الموبايل',border:OutlineInputBorder())),const SizedBox(height:12),TextField(controller:code,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'رمز التحقق',border:OutlineInputBorder())),const SizedBox(height:16),SizedBox(width:double.infinity,height:52,child:FilledButton(onPressed:busy?null:verify,style:FilledButton.styleFrom(backgroundColor:primary),child:Text(challenge==null?'إرسال الرمز':'دخول'))),if(challenge!=null)TextButton(onPressed:busy?null:request,child:const Text('إرسال الرمز مرة أخرى')),if(msg.isNotEmpty)Padding(padding:const EdgeInsets.only(top:10),child:Text(msg))])))));}
class RiderHome extends StatefulWidget{final Api api;final VoidCallback onLogout;const RiderHome({super.key,required this.api,required this.onLogout});@override State<RiderHome> createState()=>_RiderHomeState();}
class _RiderHomeState extends State<RiderHome>{
 List tasks=[]; List activeTasks=[]; Map<String,dynamic>? me; Map<String,dynamic>? earnings; bool online=false; Timer? timer;
 @override void initState(){super.initState();load();}
 @override void dispose(){timer?.cancel();super.dispose();}
 Future<void> load()async{try{final a=await api.get('/rider/tasks/available');final active=await api.get('/rider/tasks/active');final r=await api.get('/rider/me');final e=await api.get('/rider/earnings?days=30');if(mounted)setState((){tasks=List.from(a);activeTasks=List.from(active);me=Map<String,dynamic>.from(r??{});earnings=Map<String,dynamic>.from(e??{});online=me?['is_online']==true;});}catch(_){}}
 Future<void> toggle(bool v)async{await api.patch('/rider/online',{'online':v});if(mounted)setState(()=>online=v);if(v){timer?.cancel();timer=Timer.periodic(const Duration(seconds:15),(_)=>load());}else{timer?.cancel();}}
 Future<void> accept(String id)async{await api.post('/rider/tasks/$id/accept');await load();}
 Future<void> status(String id,String s)async{String? proof;if(s=='DELIVERED'){proof=await showDialog<String>(context:context,builder:(c)=>_ProofDialog());if(proof==null)return;}await api.patch('/rider/orders/$id/status',{'status':s,if(proof!=null)'proofUrl':proof});await load();}
 String ar(String s)=>{'ASSIGNED_RIDER':'مُسند للكابتن','PICKED_UP':'تم الاستلام','ON_THE_WAY':'في الطريق','DELIVERED':'تم التسليم'}[s]??s;
 Widget taskCard(dynamic x,{bool active=false}){final status=x['status'] as String;return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('${x['merchant_name']}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))),Text('${x['total']} ج.م',style:const TextStyle(fontWeight:FontWeight.bold))]),Text('${x['village']} • ${ar(status)}'),if(x['assigned_at']!=null)Text('إسناد: ${x['assigned_at']}'),const SizedBox(height:10),if(!active&&status=='READY_FOR_PICKUP')SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>accept(x['id']),style:FilledButton.styleFrom(backgroundColor:primary),icon:const Icon(Icons.check),label:const Text('قبول المهمة')))else if(active)Wrap(spacing:8,runSpacing:8,children:[if(status=='ASSIGNED_RIDER')FilledButton(onPressed:()=>status==status?this.status(x['id'],'PICKED_UP'):null,child:const Text('استلمت الطلب')),if(status=='PICKED_UP')FilledButton(onPressed:()=>this.status(x['id'],'ON_THE_WAY'),child:const Text('بدأت التوصيل')),if(status=='ON_THE_WAY')FilledButton(onPressed:()=>this.status(x['id'],'DELIVERED'),style:FilledButton.styleFrom(backgroundColor:primary),child:const Text('تم التسليم'))])])));}
 @override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(backgroundColor:primary,foregroundColor:Colors.white,title:const Text('جايك — الكابتن'),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh)),IconButton(onPressed:onLogout,icon:const Icon(Icons.logout))]),body:RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(16),children:[Card(child:ListTile(leading:CircleAvatar(backgroundColor:online?primary:Colors.grey,child:const Icon(Icons.two_wheeler,color:Colors.white)),title:Text(online?'متصل ومستعد للطلبات':'غير متصل',style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(me?['name']??'كابتن جايك'),trailing:Switch(value:online,onChanged:toggle))),const SizedBox(height:10),if(earnings!=null)Card(child:ListTile(title:const Text('ملخص آخر 30 يومًا',style:TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('التسليمات: ${earnings!['deliveryCount']} • رسوم التوصيل: ${earnings!['totalDeliveryFees']} ج.م'))),const SizedBox(height:12),if(activeTasks.isNotEmpty)const Text('المهمة الحالية',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),...activeTasks.map((x)=>taskCard(x,active:true)),const SizedBox(height:10),const Text('المهام المتاحة',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:8),...tasks.map((x)=>taskCard(x)),if(tasks.isEmpty&&activeTasks.isEmpty)const Padding(padding:EdgeInsets.all(36),child:Center(child:Text('لا توجد مهام متاحة حاليًا')))]))));}
}
class _ProofDialog extends StatefulWidget{ @override State<_ProofDialog> createState()=>_ProofDialogState(); }
class _ProofDialogState extends State<_ProofDialog>{final c=TextEditingController();@override Widget build(BuildContext context)=>AlertDialog(title:const Text('إثبات التسليم'),content:TextField(controller:c,decoration:const InputDecoration(labelText:'رابط صورة/إثبات التسليم',hintText:'https://...'),keyboardType:TextInputType.url),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,c.text.trim().isEmpty?null:c.text.trim()),child:const Text('تأكيد'))]);}
