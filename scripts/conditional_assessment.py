"""Reviewed, cited all-of conditions. Offline only; never grants approval."""
from dataclasses import dataclass
from datetime import date
from assess_requirements import Evidence


@dataclass(frozen=True)
class Clause:
    id: str
    source_version: str
    page: int
    reviewed: bool


@dataclass(frozen=True)
class Rule:
    id: str
    concept: str
    source_version: str
    clauses: tuple[Clause, ...]
    applies_if: tuple[str, ...] = ()
    except_if: tuple[str, ...] = ()


def evaluate(rule: Rule, evidence: list[Evidence], *, supplier_id: str,
             as_of: date, expected_version: str) -> dict:
    """Conditions use reviewed evidence assertions; missing is not false.

    All referenced source clauses must be reviewed. A current negative condition
    disproves an all-of predicate; a conflict never silently authorizes it.
    """
    if not supplier_id or not expected_version or type(as_of) is not date:
        raise ValueError('Explicit supplier, source version and date required')
    if not rule.id or not rule.concept or not rule.clauses:
        raise ValueError('Rule identity and cited clauses required')
    if len({c.id for c in rule.clauses}) != len(rule.clauses):
        raise ValueError('Duplicate clause identity')
    if any(not c.id or type(c.page) is not int or c.page < 1 or type(c.reviewed) is not bool
           or not c.source_version for c in rule.clauses):
        raise ValueError('Invalid clause citation')
    for conditions in (rule.applies_if, rule.except_if):
        if any(not c or not isinstance(c, str) for c in conditions) or len(set(conditions)) != len(conditions):
            raise ValueError('Invalid condition concepts')
    if len({e.id for e in evidence}) != len(evidence):
        raise ValueError('Duplicate evidence identity')
    if any(not e.id or type(e.verified) is not bool or type(e.assertion) is not bool
           or e.valid_from > e.valid_to for e in evidence):
        raise ValueError('Invalid evidence')
    used = set()

    def result(status, reason):
        return dict(requirement_id=rule.id, status=status, reason=reason,
                    source_version=rule.source_version, as_of=as_of.isoformat(),
                    supplier_id=supplier_id, clause_ids=[c.id for c in rule.clauses],
                    evidence_ids=sorted(used), rule_version='conditional-1')

    if rule.source_version != expected_version or any(c.source_version != expected_version for c in rule.clauses):
        return result('unknown', 'STALE_SOURCE_VERSION')
    if not all(c.reviewed for c in rule.clauses):
        return result('unknown', 'SOURCE_RELATIONSHIPS_NOT_REVIEWED')
    current = [e for e in evidence if e.supplier_id == supplier_id and e.verified
               and e.valid_from <= as_of <= e.valid_to]

    def state(concept):
        rows = [e for e in current if e.concept == concept]
        used.update(e.id for e in rows)
        values = {e.assertion for e in rows}
        return 'conflicting' if len(values) > 1 else next(iter(values)) if values else None

    def all_of(concepts):
        values = [state(c) for c in concepts]
        if 'conflicting' in values:
            return 'conflicting'
        if False in values:
            return False
        return None if None in values else True

    applies = all_of(rule.applies_if)
    if applies == 'conflicting':
        return result('conflicting', 'APPLICABILITY_EVIDENCE_CONFLICT')
    if applies is False:
        return result('not_applicable', 'APPLICABILITY_DISPROVED')
    if applies is None:
        return result('unknown', 'APPLICABILITY_UNRESOLVED')
    exemption = all_of(rule.except_if) if rule.except_if else False
    if exemption == 'conflicting':
        return result('conflicting', 'EXCEPTION_EVIDENCE_CONFLICT')
    if exemption is True:
        return result('not_applicable', 'REVIEWED_COMPOUND_EXCEPTION_SUPPORTED')
    direct = state(rule.concept)
    if direct == 'conflicting':
        return result('conflicting', 'DIRECT_EVIDENCE_CONFLICT')
    if direct is True:
        return result('supported', 'VERIFIED_DIRECT_EVIDENCE')
    if direct is False and exemption is None:
        return result('unknown', 'EXCEPTION_APPLICABILITY_UNRESOLVED')
    if direct is False:
        return result('gap', 'VERIFIED_DIRECT_EVIDENCE')
    return result('unknown', 'NO_CURRENT_VERIFIED_EVIDENCE')
