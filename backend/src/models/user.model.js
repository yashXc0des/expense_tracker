import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';

const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
    index: true,
  },
  passwordHash: { type: String, required: true },
  name: { 
    type: String, 
    default: function() { 
      // Extract name from email (part before @) if not provided
      return this.email?.split('@')[0] || 'User'; 
    } 
  },
  refreshTokens: [{ type: String }], // stored hashed
  createdAt: { type: Date, default: Date.now },
});

userSchema.methods.comparePassword = async function (plain) {
  return bcrypt.compare(plain, this.passwordHash);
};

userSchema.pre('save', async function (next) {
  if (!this.isModified('passwordHash')) return next();
  this.passwordHash = await bcrypt.hash(this.passwordHash, 12);
  next();
});

export default mongoose.model('User', userSchema);
