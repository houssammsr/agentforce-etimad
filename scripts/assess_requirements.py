"""Offline, deterministic evidence assessment. No uploads, org writes or approval.

Reviewed requirement relationships are inputs, never inferred procurement law.
"""
from dataclasses import dataclass
from datetime import date
from typing import Literal

Status = Literal['supported', 'gap', 'unknown', 'conflicting', 'not_applicable']


@dataclass(frozen=True)
class Requirement:
    id: str
    source_version: str
    concept: str
    page: int
    reviewed: bool
    exception_evidence_concept: str | None = None


@dataclass(frozen=True)
class Evidence:
    id: str
    supplier_id: str
    concept: str
    verified: bool
    valid_from: date
    valid_to: date
    assertion: bool = True


@dataclass(frozen=True)
class Assessment:
    requirement_id: str
    source_version: str
    as_of: date
    status: Status
    reason: str
    evidence_ids: tuple[str, ...]
    rule_version: str = 'phase3.1'


def assess(requirement: Requirement, evidence: list[Evidence], *,
           supplier_id: str, as_of: date, expected_version: str) -> Assessment:
    """Missing/expired evidence is unknown, not proof of noncompliance.

    assertion=False represents independently verified negative evidence, not
    absence. Exception evidence applies only to the explicitly linked rule.
    """
    if not supplier_id or not expected_version:
        raise ValueError('Explicit supplier and source version required')
    if not requirement.id or requirement.page < 1 or not requirement.concept:
        raise ValueError('Invalid requirement identity/citation')
    if any(e.valid_from > e.valid_to for e in evidence):
        raise ValueError('Invalid evidence validity interval')
    ids = [e.id for e in evidence]
    if len(ids) != len(set(ids)):
        raise ValueError('Duplicate evidence identity')

    def result(status, reason, rows=()):
        return Assessment(requirement.id, requirement.source_version, as_of,
                          status, reason, tuple(sorted(e.id for e in rows)))

    if requirement.source_version != expected_version:
        return result('unknown', 'STALE_SOURCE_VERSION')
    if not requirement.reviewed:
        return result('unknown', 'REQUIREMENT_NOT_REVIEWED')
    current = [e for e in evidence if e.supplier_id == supplier_id and
               e.verified and e.valid_from <= as_of <= e.valid_to]

    def matching(concept):
        return [e for e in current if e.concept == concept]

    def conflicting(rows):
        return {e.assertion for e in rows} == {True, False}

    exceptions = matching(requirement.exception_evidence_concept)
    if conflicting(exceptions):
        return result('conflicting', 'EXCEPTION_EVIDENCE_CONFLICT', exceptions)
    if any(e.assertion for e in exceptions):
        return result('not_applicable', 'REVIEWED_EXCEPTION_SUPPORTED', exceptions)
    direct = matching(requirement.concept)
    if conflicting(direct):
        return result('conflicting', 'DIRECT_EVIDENCE_CONFLICT', direct)
    if direct:
        return result('supported' if direct[0].assertion else 'gap',
                      'VERIFIED_DIRECT_EVIDENCE', direct)
    return result('unknown', 'NO_CURRENT_VERIFIED_EVIDENCE')


def assess_all(requirements, evidence, *, supplier_id, as_of, expected_version):
    """Assess multiple linked requirements without mutating source inputs."""
    if len({r.id for r in requirements}) != len(requirements):
        raise ValueError('Duplicate requirement identity')
    return [assess(r, evidence, supplier_id=supplier_id, as_of=as_of,
                   expected_version=expected_version) for r in requirements]
