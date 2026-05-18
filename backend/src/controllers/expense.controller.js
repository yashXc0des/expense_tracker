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
    console.log('[EXPENSE] createExpense request - user:', req.user.id, 'amount:', amount, 'category:', category, 'has_image:', !!req.file);

    // 1. Upload image to R2 (if provided)
    let imageKey = null,
      imageUrl = null;
    if (req.file) {
      console.log('[EXPENSE] uploading image to R2 - size:', req.file.size);
      ({ key: imageKey, url: imageUrl } = await R2Service.uploadReceiptImage(
        req.user.id,
        req.file.buffer,
        req.file.mimetype
      ));
      console.log('[EXPENSE] image uploaded - key:', imageKey);
    }

    // 2. Run OCR in parallel (non-blocking)
    console.log('[EXPENSE] running OCR extraction...');
    const ocrPromise = req.file ? OcrService.extractReceiptData(req.file.buffer) : Promise.resolve(null);

    const ocrData = await ocrPromise;
    console.log('[EXPENSE] OCR extraction complete - data:', ocrData);

    // 3. Build expense document
    console.log('[EXPENSE] creating expense document in MongoDB');
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
    console.log('[EXPENSE] expense created - id:', expense._id);

    // 4. Update journey totals if linked
    if (journeyId) {
      console.log('[EXPENSE] updating journey totals - journeyId:', journeyId);
      await Journey.findByIdAndUpdate(journeyId, {
        $inc: { totalAmount: parseFloat(amount), expenseCount: 1 },
      });
      console.log('[EXPENSE] journey updated');
    }

    console.log('[EXPENSE] createExpense success');
    res.status(201).json({ success: true, data: expense });
  } catch (err) {
    console.error('[EXPENSE] createExpense error:', err.message);
    next(err);
  }
};

export const extractExpenseOcr = async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Image file is required' });
    }

    const ocrData = await OcrService.extractReceiptData(req.file.buffer);
    if (!ocrData) {
      return res.status(503).json({ error: 'OCR service unavailable' });
    }

    // Return both backend-normalized and mobile-friendly keys.
    res.json({
      raw_text: ocrData.rawText ?? '',
      merchant_name: ocrData.merchantName ?? null,
      total_amount: ocrData.detectedAmount ?? null,
      date: ocrData.detectedDate ? new Date(ocrData.detectedDate).toISOString() : null,
      confidence: ocrData.confidence ?? 0,
      ocrData,
    });
  } catch (err) {
    next(err);
  }
};

export const getExpenses = async (req, res, next) => {
  try {
    const { page = 1, limit = 20, category, journeyId, search, startDate, endDate } = req.query;
    console.log('[EXPENSE] getExpenses request - user:', req.user.id, 'page:', page, 'limit:', limit, 'category:', category);

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

    console.log('[EXPENSE] getExpenses success - returned:', expenses.length, 'total:', total);
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
    console.error('[EXPENSE] getExpenses error:', err.message);
    next(err);
  }
};

export const deleteExpense = async (req, res, next) => {
  try {
    console.log('[EXPENSE] deleteExpense request - user:', req.user.id, 'expenseId:', req.params.id);
    const expense = await Expense.findOne({
      _id: req.params.id,
      userId: req.user.id,
      isDeleted: false,
    });
    if (!expense) {
      console.log('[EXPENSE] deleteExpense failed - expense not found:', req.params.id);
      return res.status(404).json({ error: 'Not found' });
    }

    // Soft delete
    console.log('[EXPENSE] soft deleting expense:', req.params.id);
    expense.isDeleted = true;
    await expense.save();

    // Update journey totals
    if (expense.journeyId) {
      console.log('[EXPENSE] updating journey totals after delete - journeyId:', expense.journeyId);
      await Journey.findByIdAndUpdate(expense.journeyId, {
        $inc: { totalAmount: -expense.amount, expenseCount: -1 },
      });
    }

    console.log('[EXPENSE] deleteExpense success');
    res.json({ success: true, message: 'Expense deleted' });
  } catch (err) {
    console.error('[EXPENSE] deleteExpense error:', err.message);
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
