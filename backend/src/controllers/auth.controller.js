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
    const existing = await User.findOne({ email });
    if (existing) return res.status(409).json({ error: 'Email already registered' });

    const user = await User.create({ email, name, passwordHash: password });
    const access = signAccess(user._id);
    const refresh = signRefresh(user._id);

    // Store hashed refresh token
    user.refreshTokens.push(crypto.createHash('sha256').update(refresh).digest('hex'));
    await user.save();

    res.status(201).json({
      accessToken: access,
      refreshToken: refresh,
      user: { id: user._id, name: user.name, email: user.email },
    });
  } catch (err) {
    next(err);
  }
};

export const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user || !(await user.comparePassword(password)))
      return res.status(401).json({ error: 'Invalid credentials' });

    const access = signAccess(user._id);
    const refresh = signRefresh(user._id);

    user.refreshTokens.push(crypto.createHash('sha256').update(refresh).digest('hex'));
    if (user.refreshTokens.length > 5) user.refreshTokens.shift(); // keep max 5 devices
    await user.save();

    res.json({
      accessToken: access,
      refreshToken: refresh,
      user: { id: user._id, name: user.name, email: user.email },
    });
  } catch (err) {
    next(err);
  }
};

export const refresh = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return res.status(401).json({ error: 'No token' });

    const payload = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
    const hashed = crypto.createHash('sha256').update(refreshToken).digest('hex');
    const user = await User.findById(payload.sub);

    if (!user || !user.refreshTokens.includes(hashed))
      return res.status(401).json({ error: 'Invalid refresh token' });

    const newAccess = signAccess(user._id);
    res.json({ accessToken: newAccess });
  } catch (err) {
    next(err);
  }
};

export const logout = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    if (refreshToken) {
      const hashed = crypto.createHash('sha256').update(refreshToken).digest('hex');
      await User.updateOne({ _id: req.user.id }, {
        $pull: { refreshTokens: hashed },
      });
    }
    res.json({ message: 'Logged out' });
  } catch (err) {
    next(err);
  }
};
