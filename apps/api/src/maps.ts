export type LatLng={lat:number;lon:number};
export function mapProviderConfig(){
  return {provider:process.env.MAP_PROVIDER||'openstreetmap', apiKeyConfigured:Boolean(process.env.MAP_API_KEY)};
}
