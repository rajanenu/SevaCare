import { Role, TenantKey } from './theme';

export type Hospital = {
  id: string;
  publicId: string;
  name: string;
  city: string;
  distance: string;
  specialty: string;
  theme: TenantKey;
  saved?: boolean;
};

export type Doctor = {
  id: string;
  publicId: string;
  name: string;
  specialty: string;
  hospitalId: string;
  availability: string;
  rating: string;
  fee: string;
  experience: string;
};

export type Patient = {
  id: string;
  publicId: string;
  hospitalId: string;
  name: string;
  ageBand: string;
  status: 'active' | 'disabled';
  lastVisit: string;
};

export type Appointment = {
  id: string;
  hospitalId: string;
  patientId: string;
  doctor: string;
  hospital: string;
  slot: string;
  status: 'upcoming' | 'past' | 'completed' | 'cancelled';
  note: string;
};

export type Metric = {
  label: string;
  value: string;
  trend: string;
};

export const hospitals: Hospital[] = [
  {
    id: 'aurora',
    publicId: 'T-1001',
    name: 'Aurora Multispeciality',
    city: 'Hyderabad',
    distance: '1.2 km',
    specialty: 'Cardiac, ortho, women care',
    theme: 'premium',
    saved: true,
  },
  {
    id: 'greenleaf',
    publicId: 'T-1002',
    name: 'GreenLeaf Family Clinic',
    city: 'Warangal',
    distance: '2.9 km',
    specialty: 'Primary care, pediatrics, diagnostics',
    theme: 'clinic',
    saved: true,
  },
  {
    id: 'serene',
    publicId: 'T-1003',
    name: 'Serene Heart Centre',
    city: 'Vijayawada',
    distance: '6.1 km',
    specialty: 'Heart and preventive wellness',
    theme: 'premium',
  },
  {
    id: 'navajeevan',
    publicId: 'T-1004',
    name: 'Navajeevan Community Hospital',
    city: 'Karimnagar',
    distance: '4.5 km',
    specialty: 'General medicine, lab, pharmacy',
    theme: 'clinic',
  },
];

export const doctors: Doctor[] = [
  {
    id: 'dr-meera',
    publicId: 'D-1001',
    name: 'Dr. Meera Rao',
    specialty: 'Cardiologist',
    hospitalId: 'aurora',
    availability: 'Today · 6 slots left',
    rating: '4.9',
    fee: '₹900',
    experience: '14Y+ Exp',
  },
  {
    id: 'dr-arjun',
    publicId: 'D-1002',
    name: 'Dr. Arjun Varma',
    specialty: 'Orthopedic Surgeon',
    hospitalId: 'aurora',
    availability: 'Tomorrow · 4 slots left',
    rating: '4.8',
    fee: '₹850',
    experience: '9Y+ Exp',
  },
  {
    id: 'dr-kavya',
    publicId: 'D-1003',
    name: 'Dr. Kavya Reddy',
    specialty: 'Family Medicine',
    hospitalId: 'greenleaf',
    availability: 'Today · Walk-in open',
    rating: '4.7',
    fee: '₹350',
    experience: '11Y+ Exp',
  },
  {
    id: 'dr-sanjay',
    publicId: 'D-1004',
    name: 'Dr. Sanjay Kumar',
    specialty: 'Pediatrician',
    hospitalId: 'greenleaf',
    availability: 'Tomorrow · 8 slots left',
    rating: '4.8',
    fee: '₹400',
    experience: '7Y+ Exp',
  },
];

export const patients: Patient[] = [
  {
    id: 'rohan-sharma',
    publicId: 'P-1001',
    hospitalId: 'aurora',
    name: 'Rohan Sharma',
    ageBand: '36 yrs',
    status: 'active',
    lastVisit: '12 Mar 2026',
  },
  {
    id: 'anjali-reddy',
    publicId: 'P-1002',
    hospitalId: 'aurora',
    name: 'Anjali Reddy',
    ageBand: '42 yrs',
    status: 'active',
    lastVisit: '15 Mar 2026',
  },
  {
    id: 'sita-naik',
    publicId: 'P-1003',
    hospitalId: 'greenleaf',
    name: 'Sita Naik',
    ageBand: '29 yrs',
    status: 'active',
    lastVisit: '18 Mar 2026',
  },
  {
    id: 'rahul-teja',
    publicId: 'P-1004',
    hospitalId: 'greenleaf',
    name: 'Rahul Teja',
    ageBand: '11 yrs',
    status: 'disabled',
    lastVisit: '09 Mar 2026',
  },
];

export const appointments: Appointment[] = [];

export const scheduleBlocks = [
  '09:00 - 11:00 OPD',
  '11:30 - 13:00 Video consults',
  '15:00 - 18:00 Follow-ups',
];

export const availableDates: string[] = [];
export const availableSlots: string[] = [];

export const adminMetrics: Metric[] = [
  { label: 'Daily visits', value: '128', trend: '+12%' },
  { label: 'Booked slots', value: '84%', trend: '+6%' },
  { label: 'Avg wait time', value: '14 min', trend: '-4%' },
  { label: 'Revenue today', value: '₹2.4L', trend: '+9%' },
];

export const adminSections = [
  {
    title: 'Doctor management',
    description: 'Onboard specialists, assign departments, update credentials.',
  },
  {
    title: 'Slot configuration',
    description: 'Manage OPD timing, consultation caps, and buffer windows.',
  },
  {
    title: 'Reports overview',
    description: 'Track growth, hospital utilization, and patient outcomes.',
  },
];

export const roleDescriptions: Record<Role, string> = {
  patient: 'Book care, manage appointments, and access prescriptions.',
  doctor: 'Review today’s list, complete consults, and manage schedules.',
  admin: 'Manage one hospital: doctors, hospital admins, patients, and reports.',
  platform_admin: 'Manage the full application: tenant visibility, onboarding, and platform operations.',
};