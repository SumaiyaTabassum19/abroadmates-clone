const jwt = require('jsonwebtoken');
function authenticateToken(req,res,next) {
  const [scheme,token] = (req.headers.authorization || '').split(' ');
  if (scheme !== 'Bearer' || !token) return res.status(401).json({message:'Authentication token required.'});
  try { req.user = jwt.verify(token,process.env.JWT_SECRET); next(); }
  catch { return res.status(401).json({message:'Invalid or expired token.'}); }
}
function authorizeRoles(...roles) {
  return (req,res,next) => req.user && roles.includes(req.user.role)
    ? next() : res.status(403).json({message:'You are not allowed to access this resource.'});
}
module.exports = {authenticateToken,authorizeRoles};
