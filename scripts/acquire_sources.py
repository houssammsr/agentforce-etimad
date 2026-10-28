"""Fetch allowlisted public candidates locally; never upload to Salesforce or an LLM.

Run using Python with pypdf and pypdfium2 available. Originals and extracted
text remain gitignored. Public availability does not grant redistribution rights.
"""
import hashlib
import json
from pathlib import Path
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = Path(__file__).resolve().parents[1]
MAX_BYTES = 20 * 1024 * 1024


def fetch(source):
    from pypdf import PdfReader
    result = dict(source)
    try:
        if not source['url'].startswith('https://ensan.org.sa/'):
            raise ValueError('Source is not on the explicit acquisition allowlist')
        with urllib.request.urlopen(source['url'], timeout=30) as response:
            if not response.geturl().startswith('https://ensan.org.sa/'):
                raise ValueError('Redirect outside allowed buyer domain')
            body = response.read(MAX_BYTES + 1)
        if len(body) > MAX_BYTES or not body.startswith(b'%PDF-'):
            raise ValueError('Expected PDF within 20 MiB cap')
        raw = ROOT / 'data/raw' / (source['source_id'] + '.pdf')
        raw.parent.mkdir(parents=True, exist_ok=True)
        raw.write_bytes(body)
        reader = PdfReader(raw)
        pages = [page.extract_text() or '' for page in reader.pages]
        result.update(sha256=hashlib.sha256(body).hexdigest(), bytes=len(body),
                      page_count=len(pages), local_path=raw.relative_to(ROOT).as_posix(),
                      fetched_utc=__import__('datetime').datetime.now(__import__('datetime').timezone.utc).isoformat())
        restricted = any(x in '\n'.join(pages).casefold() for x in ['top secret', 'restricted document', 'سري للغاية'])
        result['status'] = 'quarantined_marking' if restricted else 'downloaded_pending_visual_review'
        if not restricted:
            extracted = ROOT / 'data/extracted' / (source['source_id'] + '.json')
            extracted.parent.mkdir(parents=True, exist_ok=True)
            extracted.write_text(json.dumps({'source_id': source['source_id'], 'pages': [
                {'pdf_page': i + 1, 'text': text} for i, text in enumerate(pages)]}, ensure_ascii=False, indent=2), encoding='utf-8')
    except Exception as exc:
        result.update(status='unavailable', error=f'{type(exc).__name__}: {exc}')
    return result


if __name__ == '__main__':
    manifest = json.loads((ROOT / 'data/sources/candidates.json').read_text(encoding='utf-8'))
    manifest['sources'] = list(ThreadPoolExecutor(max_workers=3).map(fetch, manifest['sources']))
    out = ROOT / 'data/sources/acquisition.json'
    out.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for source in manifest['sources']:
        print(source['source_id'], source['status'], source.get('page_count'), source.get('error', ''))
