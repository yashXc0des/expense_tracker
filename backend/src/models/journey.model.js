import mongoose from 'mongoose';

const journeySchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  name: { type: String, required: true },
  description: { type: String },
  startDate: { type: Date, required: true },
  endDate: { type: Date, required: true },
  totalAmount: { type: Number, default: 0 },
  expenseCount: { type: Number, default: 0 },
  coverImageUrl: { type: String },
  tags: [String],
  isDeleted: { type: Boolean, default: false },
}, { timestamps: true });

export default mongoose.model('Journey', journeySchema);
