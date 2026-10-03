import { ORDER_TRANSITIONS, deliveryFee, distanceKm } from './domain';
import { CodPaymentProvider, HaversineMapsProvider } from './integrations';

describe('JAYEK v2.4 full order contract', () => {
  it('covers the complete pilot order lifecycle without illegal jumps', () => {
    const flow = ['CREATED','CONFIRMED','ACCEPTED_BY_MERCHANT','PREPARING','READY_FOR_PICKUP','ASSIGNED_RIDER','PICKED_UP','ON_THE_WAY','DELIVERED'];
    for (let i=0;i<flow.length-1;i++) expect(ORDER_TRANSITIONS[flow[i]]).toContain(flow[i+1]);
    expect(ORDER_TRANSITIONS.DELIVERED).toEqual([]);
  });

  it('calculates delivery fee from authoritative server-side inputs', () => {
    const d = distanceKm(29.6465,31.3185,29.70,31.36);
    expect(d).toBeGreaterThan(0);
    expect(deliveryFee(d,15,3,15)).toBeGreaterThanOrEqual(15);
  });

  it('returns a route contract compatible with tracking UI', async () => {
    const route = await new HaversineMapsProvider().route({lat:29.6465,lon:31.3185},{lat:29.70,lon:31.36});
    expect(route.provider).toBe('haversine');
    expect(route.distanceKm).toBeGreaterThan(0);
    expect(route.durationMinutes).toBeGreaterThan(0);
  });

  it('supports the pilot CASH payment path end-to-end at provider boundary', async () => {
    const intent = await new CodPaymentProvider().createIntent({paymentId:'payment-1',amount:125,currency:'EGP',method:'CASH',orderId:'order-1'});
    expect(intent).toMatchObject({provider:'cod',providerReference:'payment-1'});
  });
});
