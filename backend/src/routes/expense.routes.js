import { Router } from 'express';
import { protect } from '../middleware/auth.middleware.js';
import {
  createExpense,
  getExpenses,
  deleteExpense,
  getSummary,
  upload,
} from '../controllers/expense.controller.js';

const router = Router();
router.use(protect); // all expense routes require auth

router.post('/', upload.single('receipt'), createExpense);
router.get('/', getExpenses);
router.get('/summary', getSummary);
router.delete('/:id', deleteExpense);

export default router;
