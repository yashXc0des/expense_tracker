import Journey from '../models/journey.model.js';
import Expense from '../models/expense.model.js';

export const createJourney = async (req, res, next) => {
  try {
    const { name, description, startDate, endDate, tags } = req.body;

    const journey = await Journey.create({
      userId: req.user.id,
      name,
      description,
      startDate: new Date(startDate),
      endDate: new Date(endDate),
      tags: tags || [],
    });

    res.status(201).json({ success: true, data: journey });
  } catch (err) {
    next(err);
  }
};

export const getJourneys = async (req, res, next) => {
  try {
    const { page = 1, limit = 10 } = req.query;

    const [journeys, total] = await Promise.all([
      Journey.find({ userId: req.user.id, isDeleted: false })
        .sort({ startDate: -1 })
        .skip((page - 1) * limit)
        .limit(parseInt(limit))
        .lean(),
      Journey.countDocuments({ userId: req.user.id, isDeleted: false }),
    ]);

    res.json({
      data: journeys,
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

export const getJourneyDetail = async (req, res, next) => {
  try {
    const journey = await Journey.findOne({
      _id: req.params.id,
      userId: req.user.id,
      isDeleted: false,
    }).lean();

    if (!journey) return res.status(404).json({ error: 'Not found' });

    // Get associated expenses
    const expenses = await Expense.find({
      journeyId: journey._id,
      isDeleted: false,
    })
      .sort({ date: -1 })
      .lean();

    res.json({
      ...journey,
      expenses,
    });
  } catch (err) {
    next(err);
  }
};

export const updateJourney = async (req, res, next) => {
  try {
    const { name, description, tags, coverImageUrl } = req.body;

    const journey = await Journey.findOneAndUpdate(
      { _id: req.params.id, userId: req.user.id, isDeleted: false },
      { name, description, tags, coverImageUrl, updatedAt: new Date() },
      { new: true }
    );

    if (!journey) return res.status(404).json({ error: 'Not found' });

    res.json({ success: true, data: journey });
  } catch (err) {
    next(err);
  }
};

export const deleteJourney = async (req, res, next) => {
  try {
    const journey = await Journey.findOne({
      _id: req.params.id,
      userId: req.user.id,
      isDeleted: false,
    });

    if (!journey) return res.status(404).json({ error: 'Not found' });

    journey.isDeleted = true;
    await journey.save();

    res.json({ success: true, message: 'Journey deleted' });
  } catch (err) {
    next(err);
  }
};
