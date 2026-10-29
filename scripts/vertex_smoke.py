"""Single synthetic structured-output probe against the configured Vertex endpoint.

No PDF ingestion, Salesforce access, automatic endpoint fallback or request retry.
Local .env is read as plain key=value data, never executed. Process env wins.
"""
import json
import os
import re
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SETTINGS = {'VERTEX_API_KEY', 'GOOGLE_CLOUD_PROJECT', 'GOOGLE_CLOUD_LOCATION', 'VERTEX_MODEL'}


def settings():
    values = {}
    path = ROOT / '.env'
    if path.exists():
        for line in path.read_text(encoding='utf-8').splitlines():
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            key, separator, value = line.partition('=')
            if separator and key.strip() in SETTINGS:
                values[key.strip()] = value.strip()
    for key in SETTINGS:
        if key in os.environ:
            values[key] = os.environ[key]
    if not all(values.get(key) for key in SETTINGS):
        raise ValueError('Missing Vertex configuration; set local .env or process variables')
    for key in SETTINGS - {'VERTEX_API_KEY'}:
        if not re.fullmatch(r'[a-zA-Z0-9._-]+', values[key]):
            raise ValueError('Invalid Vertex project, location or model identifier')
    return values


def run_probe():
    config = settings()
    if config['GOOGLE_CLOUD_LOCATION'] != 'global':
        raise ValueError('This probe is configured for the user-verified global endpoint only')
    endpoint = ('https://aiplatform.googleapis.com/v1/projects/' + config['GOOGLE_CLOUD_PROJECT'] +
                '/locations/global/publishers/google/models/' + config['VERTEX_MODEL'] + ':generateContent')
    schema = {'type': 'OBJECT', 'properties': {
        'document_id': {'type': 'STRING'}, 'bid_security_percent': {'type': 'NUMBER'},
        'local_sme_exempt': {'type': 'BOOLEAN'}, 'evidence_page': {'type': 'INTEGER'}},
        'required': ['document_id', 'bid_security_percent', 'local_sme_exempt', 'evidence_page']}
    payload = {'contents': [{'role': 'user', 'parts': [{'text':
        'Extract only facts from this synthetic fixture, not a real tender. '
        'Document ID SYN-VERTEX-001. Page 2: الضمان الابتدائي بنسبة ١٪ من إجمالي العرض. '
        'تُعفى المنشآت الصغيرة والمتوسطة المحلية من الضمان الابتدائي. '
        'Return document ID, percentage, whether local SMEs are exempt, and evidence page.'}]}],
        'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 2048,
                             'responseMimeType': 'application/json', 'responseSchema': schema}}
    request = urllib.request.Request(endpoint, data=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json', 'x-goog-api-key': config['VERTEX_API_KEY']}, method='POST')
    started = time.monotonic()
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            result = json.load(response)
    except urllib.error.HTTPError as exc:
        # Do not emit request headers, credentials, response bodies or exception URLs.
        return {'status': 'failed', 'http_status': exc.code,
                'next_step': 'Stop and discuss endpoint/account configuration with user; no fallback attempted.'}
    except (urllib.error.URLError, TimeoutError):
        return {'status': 'failed', 'reason': 'Network request failed or timed out; no retry or fallback attempted.'}
    candidates = result.get('candidates', [])
    candidate = candidates[0] if candidates else {}
    text = ''.join(p.get('text', '') for p in candidate.get('content', {}).get('parts', []) if not p.get('thought'))
    try:
        extracted = json.loads(text)
    except (ValueError, TypeError):
        extracted = None
    expected = {'document_id': 'SYN-VERTEX-001', 'bid_security_percent': 1,
                'local_sme_exempt': True, 'evidence_page': 2}
    valid = (type(extracted) is dict and set(extracted) == set(expected)
             and type(extracted.get('local_sme_exempt')) is bool
             and type(extracted.get('evidence_page')) is int
             and type(extracted.get('bid_security_percent')) in (int, float)
             and extracted == expected and candidate.get('finishReason') == 'STOP')
    return {'status': 'passed' if valid else 'failed', 'http_status': 200,
            'project': config['GOOGLE_CLOUD_PROJECT'], 'location': 'global',
            'requested_model': config['VERTEX_MODEL'], 'returned_model': result.get('modelVersion'),
            'elapsed_seconds': round(time.monotonic() - started, 3),
            'finish_reason': candidate.get('finishReason'), 'schema_and_fixture_match': valid,
            'usage': result.get('usageMetadata'), 'synthetic_only': True, 'real_documents_uploaded': False}


if __name__ == '__main__':
    try:
        report = run_probe()
    except ValueError as exc:
        report = {'status': 'failed', 'reason': str(exc)}
    path = ROOT / 'local-artifacts/vertex-smoke.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))
    raise SystemExit(report['status'] != 'passed')
