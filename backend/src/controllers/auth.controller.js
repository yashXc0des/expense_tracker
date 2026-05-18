import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import User from '../models/user.model.js';

const signAccess = (userId) =>
  jwt.sign({ sub: userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN,
  });

const signRefresh = (userId) =>
  jwt.sign({ sub: userId }, process.env.JWT_REFRESH_SECRET, {
    expiresIn: process.env.JWT_REFRESH_EXPIRES_IN,
  });

export const signup = async (req, res, next) => {
  try {
    const { email, password, name } = req.body;
    console.log('[AUTH] signup request received - email:', email, 'name:', name);
    
    const existing = await User.findOne({ email });
    if (existing) {
      console.log('[AUTH] signup failed - email already registered:', email);
      return res.status(409).json({ error: 'Email already registered' });
    }

    console.log('[AUTH] creating user:', email);
    const user = await User.create({ email, name, passwordHash: password });
    console.log('[AUTH] user created:', user._id);
    
    const access = signAccess(user._id);
    const refresh = signRefresh(user._id);
    console.log('[AUTH] tokens generated for user:', user._id);

    // Store hashed refresh token
    user.refreshTokens.push(crypto.createHash('sha256').update(refresh).digest('hex'));
    await user.save();
    console.log('[AUTH] refresh token stored');

    console.log('[AUTH] signup success - sending response to client');
    res.status(201).json({
      accessToken: access,
      refreshToken: refresh,
      user: { id: user._id, name: user.name, email: user.email },
    });
  } catch (err) {
    console.error('[AUTH] signup error:', err.message);
    next(err);
  }
};

export const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    console.log('[AUTH] login request received - email:', email);
    
    const user = await User.findOne({ email });
    if (!user) {
      console.log('[AUTH] login failed - user not found:', email);
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    console.log('[AUTH] user found:', user._id, '- checking password');
    
    const passwordMatch = await user.comparePassword(password);
    if (!passwordMatch) {
      console.log('[AUTH] login failed - password mismatch for:', email);
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    console.log('[AUTH] password matched for:', email);

    const access = signAccess(user._id);
    const refresh = signRefresh(user._id);
    console.log('[AUTH] tokens generated for user:', user._id);

    user.refreshTokens.push(crypto.createHash('sha256').update(refresh).digest('hex'));
    if (user.refreshTokens.length > 5) user.refreshTokens.shift(); // keep max 5 devices
    await user.save();
    console.log('[AUTH] refresh token stored');

    console.log('[AUTH] login success - sending response to client');
    res.json({
      accessToken: access,
      refreshToken: refresh,
      user: { id: user._id, name: user.name, email: user.email },
    });
  } catch (err) {
    console.error('[AUTH] login error:', err.message);
    next(err);
  }
};

export const refresh = async (req, res, next) => {
  try {
    const { refreshToken, token } = req.body;
    const rt = refreshToken || token;
    console.log('[AUTH] refresh request received');
    
    if (!rt) {
      console.log('[AUTH] refresh failed - no token provided');
      return res.status(401).json({ error: 'No token' });
    }

    const payload = jwt.verify(rt, process.env.JWT_REFRESH_SECRET);
    console.log('[AUTH] refresh token verified for user:', payload.sub);
    
    const hashed = crypto.createHash('sha256').update(rt).digest('hex');
    const user = await User.findById(payload.sub);

    if (!user) {
      console.log('[AUTH] refresh failed - user not found:', payload.sub);
      return res.status(401).json({ error: 'Invalid refresh token' });
    }
    
    if (!user.refreshTokens.includes(hashed)) {
      console.log('[AUTH] refresh failed - token not in user store:', payload.sub);
      return res.status(401).json({ error: 'Invalid refresh token' });
    }

    const newAccess = signAccess(user._id);
    console.log('[AUTH] new access token generated for user:', user._id);
    res.json({ accessToken: newAccess });
  } catch (err) {
    console.error('[AUTH] refresh error:', err.message);
    next(err);
  }
};

export const logout = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    console.log('[AUTH] logout request received for user:', req.user.id);
    
    if (refreshToken) {
      const hashed = crypto.createHash('sha256').update(refreshToken).digest('hex');
      await User.updateOne({ _id: req.user.id }, {
        $pull: { refreshTokens: hashed },
      });
      console.log('[AUTH] refresh token removed from user:', req.user.id);
    }
    console.log('[AUTH] logout success for user:', req.user.id);
    res.json({ message: 'Logged out' });
  } catch (err) {
    console.error('[AUTH] logout error:', err.message);
    next(err);
  }
};
