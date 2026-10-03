import { ConsoleOtpProvider, HaversineMapsProvider, CodPaymentProvider, IntegrationService } from '../src/integrations';

describe('v1.1 integrations',()=>{
  it('generates a four digit OTP',()=>{ const s=new IntegrationService(); expect(s.generateOtp()).toMatch(/^\d{4}$/); });
  it('console OTP provider is deterministic for supplied code',async()=>{ const r=await new ConsoleOtpProvider().sendOtp('01000000000','4321'); expect(r.provider).toBe('console'); expect(r.code).toBe('4321'); });
  it('maps locally without external credentials',async()=>{ const r=await new HaversineMapsProvider().route({lat:29.6465,lon:31.3185},{lat:29.6565,lon:31.3285}); expect(r.provider).toBe('haversine'); expect(r.distanceKm).toBeGreaterThan(0); });
  it('cash provider creates a reference',async()=>{ const r=await new CodPaymentProvider().createIntent({paymentId:'p1',amount:100,currency:'EGP',method:'CASH',orderId:'o1'}); expect(r.providerReference).toBe('p1'); });
});
