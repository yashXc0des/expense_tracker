import { Router } from 'express';
import { protect } from '../middleware/auth.middleware.js';
import {
  createJourney,
  getJourneys,
  getJourneyDetail,
  updateJourney,
  deleteJourney,
} from '../controllers/journey.controller.js';

const router = Router();
router.use(protect); // all journey routes require auth

router.post('/', createJourney);
router.get('/', getJourneys);
router.get('/:id', getJourneyDetail);
router.patch('/:id', updateJourney);
router.delete('/:id', deleteJourney);

export default router;
