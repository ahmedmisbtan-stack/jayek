import { API_VERSION, ORDER_TRANSITIONS, distanceKm, deliveryFee } from './domain';

describe('JAYEK domain invariants', () => {
  it('uses the pilot-ready API version', () => expect(API_VERSION).toBe('2.3.0'));
  it('allows only the intended order lifecycle', () => {
    expect(ORDER_TRANSITIONS.CREATED).toContain('CONFIRMED');
    expect(ORDER_TRANSITIONS.CONFIRMED).toContain('ACCEPTED_BY_MERCHANT');
    expect(ORDER_TRANSITIONS.ON_THE_WAY).toContain('DELIVERED');
    expect(ORDER_TRANSITIONS.DELIVERED).toEqual([]);
  });
  it('calculates geographic distance in kilometers', () => {
    expect(distanceKm(29.6465,31.3185,29.6465,31.3185)).toBeCloseTo(0, 8);
    expect(distanceKm(29.6465,31.3185,29.6565,31.3185)).toBeGreaterThan(1);
  });
  it('applies minimum delivery fee and rounds to two decimals', () => {
    expect(deliveryFee(0,15,3,15)).toBe(15);
    expect(deliveryFee(2.5,15,3,15)).toBe(22.5);
  });
});
