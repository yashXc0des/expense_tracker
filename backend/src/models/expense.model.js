import mongoose from 'mongoose';

const expenseSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  journeyId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Journey',
    default: null,
    index: true,
  },
  amount: { type: Number, required: true },
  currency: { type: String, default: 'INR' },
  category: {
    type: String,
    enum: ['Food', 'Travel', 'Fuel', 'Entertainment', 'Hotel', 'Parking', 'Utilities', 'Shopping', 'Health', 'Other'],
    required: true,
  },
  note: { type: String, trim: true },
  date: { type: Date, default: Date.now },
  imageKey: { type: String }, // R2 object key
  imageUrl: { type: String }, // CDN URL
  ocrData: {
    rawText: String,
    merchantName: String,
    detectedAmount: Number,
    detectedDate: Date,
    confidence: Number, // 0-1
  },
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point',
    },
    coordinates: { type: [Number], default: [0, 0] }, // [lng, lat]
  },
  isDeleted: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
}, { timestamps: true });

expenseSchema.index({ location: '2dsphere' });
expenseSchema.index({ userId: 1, date: -1 });
expenseSchema.index({ userId: 1, journeyId: 1, date: -1 });

export default mongoose.model('Expense', expenseSchema);
