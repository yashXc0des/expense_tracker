import { randomBytes } from 'crypto';
import fs from 'fs';
import path from 'path';

const envPath = path.join(process.cwd(), '.env');

function generateSecret(bytes = 48) {
  return randomBytes(bytes).toString('hex');
}

function updateEnv(secret1, secret2) {
  if (!fs.existsSync(envPath)) {
    console.error('.env not found at', envPath);
    process.exit(1);
  }

  let env = fs.readFileSync(envPath, 'utf8');

  env = env.replace(/JWT_SECRET=.*\n?/, `JWT_SECRET=${secret1}\n`);
  env = env.replace(/JWT_REFRESH_SECRET=.*\n?/, `JWT_REFRESH_SECRET=${secret2}\n`);

  fs.writeFileSync(envPath, env, { encoding: 'utf8' });
  console.log('Updated .env with new JWT secrets');
}

const s1 = generateSecret(32);
const s2 = generateSecret(32);
updateEnv(s1, s2);
console.log('JWT_SECRET=', s1);
console.log('JWT_REFRESH_SECRET=', s2);
