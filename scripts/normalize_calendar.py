"""Deterministic date-only conversion; no inferred time or timezone."""
import re
from hijridate import Hijri


def normalize_hijri(literal):
    if type(literal) is not str:
        raise ValueError('Explicit Hijri date string required')
    digits = str.maketrans('٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789')
    value = literal.translate(digits).strip()
    match = re.fullmatch(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})\s*(?:هـ|ه|AH)?', value)
    if not match:
        raise ValueError('Expected explicit year/month/day Hijri date')
    year, month, day = map(int, match.groups())
    if not 1440 <= year <= 1500:
        raise ValueError('Project supports Umm al-Qura years 1440 through 1500 only')
    converted = Hijri(year, month, day).to_gregorian()
    return {'source_literal': literal, 'calendar': 'umm_al_qura',
            'hijri_iso': f'{year:04d}-{month:02d}-{day:02d}',
            'gregorian_iso': converted.isoformat(), 'time': None, 'timezone': None,
            'converter': 'hijridate==2.5.0'}
