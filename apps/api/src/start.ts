import { Pool } from 'pg';
import { readFile } from 'fs/promises';
import { join } from 'path';

async function main(){
  if(String(process.env.AUTO_MIGRATE || 'false').toLowerCase() !== 'true') return;
  const pool=new Pool({connectionString:process.env.DATABASE_URL, max:Number(process.env.DB_POOL_MAX||5)});
  try{
    const sql=await readFile(join(process.cwd(),'schema.sql'),'utf8');
    await pool.query(sql);
    console.log(JSON.stringify({event:'database_schema_ready'}));
  } finally { await pool.end(); }
}
main().catch(e=>{ console.error(e); process.exit(1); });
