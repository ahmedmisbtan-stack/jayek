import { CodPaymentProvider, GenericHostedPaymentProvider, IntegrationService } from './integrations';

describe('JAYEK production integrations', () => {
  const original = {...process.env};
  afterEach(() => { process.env = {...original}; });

  it('uses constant-time webhook signature comparison', () => {
    process.env.PAYMENT_WEBHOOK_SECRET = 'secret';
    const provider = new GenericHostedPaymentProvider();
    const crypto = require('crypto');
    const payload = '{"id":"evt_1"}';
    const sig = crypto.createHmac('sha256','secret').update(payload).digest('hex');
    expect(provider.verifyWebhook(payload,sig).valid).toBe(true);
    expect(provider.verifyWebhook(payload,sig.slice(0,-1)+'0').valid).toBe(false);
  });

  it('keeps COD available without a remote payment gateway', async () => {
    const p = new CodPaymentProvider();
    const result = await p.createIntent({paymentId:'p1',amount:100,currency:'EGP',method:'CASH',orderId:'o1'});
    expect(result.provider).toBe('cod');
  });

  it('rejects incomplete production configuration', () => {
    process.env.NODE_ENV='production';
    process.env.JWT_SECRET='short';
    expect(() => new IntegrationService()).toThrow(/Production integration configuration incomplete/);
  });
});
