import multer from 'multer';
import Expense from '../models/expense.model.js';
import Journey from '../models/journey.model.js';
import { R2Service } from '../services/r2.service.js';
import { OcrService } from '../services/ocr.service.js';

// Store upload in memory (max 10MB)
export const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (_, file, cb) => {
    if (!file.mimetype.startsWith('image/')) cb(new Error('Images only'));
    else cb(null, true);
  },
});

export const createExpense = async (req, res, next) => {
  try {
    const { amount, category, note, date, journeyId, latitude, longitude } = req.body;

    // 1. Upload image to R2 (if provided)
    let imageKey = null,
      imageUrl = null;
    if (req.file) {
      ({ key: imageKey, url: imageUrl } = await R2Service.uploadReceiptImage(
        req.user.id,
        req.file.buffer,
        req.file.mimetype
      ));
    }

    // 2. Run OCR in parallel (non-blocking)
    const ocrPromise = req.file ? OcrService.extractReceiptData(req.file.buffer) : Promise.resolve(null);

    const ocrData = await ocrPromise;

    // 3. Build expense document
    const expense = await Expense.create({
      userId: req.user.id,
      journeyId: journeyId || null,
      amount: parseFloat(amount),
      category,
      note,
      date: date ? new Date(date) : new Date(),
      imageKey,
      imageUrl,
      ocrData,
      location:
        latitude && longitude
          ? { type: 'Point', coordinates: [parseFloat(longitude), parseFloat(latitude)] }
          : undefined,
    });

    // 4. Update journey totals if linked
    if (journeyId) {
      await Journey.findByIdAndUpdate(journeyId, {
        $inc: { totalAmount: parseFloat(amount), expenseCount: 1 },
      });
    }

    res.status(201).json({ success: true, data: expense });
  } catch (err) {
    next(err);
  }
};

export const getExpenses = async (req, res, next) => {
  try {
    const { page = 1, limit = 20, category, journeyId, search, startDate, endDate } = req.query;

    const filter = { userId: req.user.id, isDeleted: false };
    if (category) filter.category = category;
    if (journeyId) filter.journeyId = journeyId;
    if (search)
      filter.$or = [
        { note: { $regex: search, $options: 'i' } },
        { 'ocrData.merchantName': { $regex: search, $options: 'i' } },
      ];
    if (startDate || endDate) {
      filter.date = {};
      if (startDate) filter.date.$gte = new Date(startDate);
      if (endDate) filter.date.$lte = new Date(endDate);
    }

    const [expenses, total] = await Promise.all([
      Expense.find(filter)
        .sort({ date: -1 })
        .skip((page - 1) * limit)
        .limit(parseInt(limit))
        .lean(),
      Expense.countDocuments(filter),
    ]);

    res.json({
      data: expenses,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (err) {
    next(err);
  }
};

export const deleteExpense = async (req, res, next) => {
  try {
    const expense = await Expense.findOne({
      _id: req.params.id,
      userId: req.user.id,
      isDeleted: false,
    });
    if (!expense) return res.status(404).json({ error: 'Not found' });

    // Soft delete
    expense.isDeleted = true;
    await expense.save();

    // Update journey totals
    if (expense.journeyId) {
      await Journey.findByIdAndUpdate(expense.journeyId, {
        $inc: { totalAmount: -expense.amount, expenseCount: -1 },
      });
    }

    res.json({ success: true, message: 'Expense deleted' });
  } catch (err) {
    next(err);
  }
};

export const getSummary = async (req, res, next) => {
  try {
    const now = new Date();
    const startOfDay = new Date(now.setHours(0, 0, 0, 0));
    const startOfWeek = new Date(now);
    startOfWeek.setDate(now.getDate() - now.getDay());
    startOfWeek.setHours(0, 0, 0, 0);
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    const pipeline = (startDate) => [
      { $match: { userId: req.user.id, isDeleted: false, date: { $gte: startDate } } },
      { $group: { _id: null, total: { $sum: '$amount' }, count: { $sum: 1 } } },
    ];

    const [today, week, month] = await Promise.all([
      Expense.aggregate(pipeline(startOfDay)),
      Expense.aggregate(pipeline(startOfWeek)),
      Expense.aggregate(pipeline(startOfMonth)),
    ]);

    res.json({
      today: { total: today[0]?.total ?? 0, count: today[0]?.count ?? 0 },
      week: { total: week[0]?.total ?? 0, count: week[0]?.count ?? 0 },
      month: { total: month[0]?.total ?? 0, count: month[0]?.count ?? 0 },
    });
  } catch (err) {
    next(err);
  }
};
