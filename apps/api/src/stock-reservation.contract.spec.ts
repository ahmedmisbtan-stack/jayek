import { deliveryFee } from './domain';

describe('stock reservation contract',()=>{
  it('keeps delivery pricing deterministic while reservation remains transactional',()=>{
    expect(deliveryFee(0,15,3,15)).toBe(15);
    expect(deliveryFee(2,15,3,15)).toBe(21);
  });
});
