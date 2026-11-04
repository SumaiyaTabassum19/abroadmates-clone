require('dotenv').config();
const app = require('./app');
const port = Number(process.env.PORT || 5000);
if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
  console.error('Set JWT_SECRET in .env to a random secret of at least 32 characters.');
  process.exit(1);
}
app.listen(port,()=>console.log(`AbroadMates API running at http://localhost:${port}`));
