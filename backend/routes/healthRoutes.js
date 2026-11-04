const router = require('express').Router();
const pool = require('../config/database');
const asyncHandler = require('../utils/asyncHandler');
router.get('/',asyncHandler(async (_req,res) => {
  await pool.query('SELECT 1');
  res.json({status:'ok',message:'AbroadMates API and database are connected.'});
}));
module.exports = router;
