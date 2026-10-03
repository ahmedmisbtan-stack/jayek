export const API_VERSION = '3.3.0';

export const ORDER_TRANSITIONS: Record<string, string[]> = {
  CREATED: ['PAYMENT_PENDING', 'CONFIRMED', 'CANCELLED'],
  PAYMENT_PENDING: ['CONFIRMED', 'FAILED_PAYMENT'],
  CONFIRMED: ['ACCEPTED_BY_MERCHANT', 'REJECTED'],
  ACCEPTED_BY_MERCHANT: ['PREPARING'],
  PREPARING: ['READY_FOR_PICKUP'],
  READY_FOR_PICKUP: ['ASSIGNED_RIDER'],
  ASSIGNED_RIDER: ['PICKED_UP'],
  PICKED_UP: ['ON_THE_WAY'],
  ON_THE_WAY: ['DELIVERED'],
  DELIVERED: [], CANCELLED: [], FAILED_PAYMENT: [], REJECTED: [], REFUNDED: [],
};

export function distanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const rad = (x: number) => x * Math.PI / 180;
  const dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function deliveryFee(distance: number, base: number, perKm: number, minimum: number): number {
  return Number(Math.max(minimum, base + perKm * distance).toFixed(2));
}
