"""Validate the synthetic Wiki acceptance corpus without a live database."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "docs/wiki-stage-0/fixtures.json"


def validate() -> None:
    data = json.loads(FIXTURES.read_text(encoding="utf-8"))
    samples = {item["id"]: item for item in data["samples"]}
    assert set(samples) == {"A", "B", "C", "D", "E", "F", "L1", "L2"}
    assert data["synthetic"] is True
    expected = data["expected"]
    assert expected["same_topic"] == ["A", "B", "C"]
    assert expected["conflict"]["sample_ids"] == ["A", "C"]
    assert expected["unrelated"] == ["D"]
    assert expected["degraded"] == ["E"]
    assert expected["revision_of"] == {"F": "A"}
    assert expected["same_session"] == ["L1", "L2"]
    assert expected["independent_corroboration"]["L1-L2"] is False
    assert samples["F"]["media_id"] == samples["A"]["media_id"]
    assert samples["F"]["transcript_version"] > samples["A"]["transcript_version"]
    assert samples["F"]["analysis_version"] > samples["A"]["analysis_version"]
    assert samples["L1"]["session_id"] == samples["L2"]["session_id"]
    assert samples["L1"]["part_index"] < samples["L2"]["part_index"]

    media_ids = [samples[key]["media_id"] for key in samples if key != "F"]
    assert len(media_ids) == len(set(media_ids))
    for key, sample in samples.items():
        assert expected["expected_pages"][key] == f"videos/{sample['media_id']}.md"
        assert sample["transcript_id"] and sample["analysis_version"] > 0
        segments = {segment["id"]: segment for segment in sample["segments"]}
        assert len(segments) == len(sample["segments"])
        for segment in segments.values():
            assert 0 <= segment["start_ms"] < segment["end_ms"]
            assert segment["text"].strip()
        analysis = sample["analysis"]
        assert set(analysis) == {"summary", "chapters", "knowledge_points", "suggested_qa"}
        assert analysis["summary"]["summary"].strip()
        assert bool(analysis["summary"]["degraded"]) == (key == "E")
        entries = (
            analysis["chapters"]
            + analysis["knowledge_points"]
            + analysis["suggested_qa"]
            + analysis["summary"]["degraded_ranges"]
        )
        assert all(analysis[name] for name in ("chapters", "knowledge_points", "suggested_qa"))
        for entry in entries:
            citation = entry["citation"]
            assert citation["segment_ids"]
            assert citation["start_ms"] <= citation["end_ms"]
            for segment_id in citation["segment_ids"]:
                assert segment_id in segments, (key, segment_id)
            cited = [segments[segment_id] for segment_id in citation["segment_ids"]]
            assert citation["start_ms"] >= min(item["start_ms"] for item in cited)
            assert citation["end_ms"] <= max(item["end_ms"] for item in cited)
            if key == "E" and entry not in analysis["summary"]["degraded_ranges"]:
                assert entry["degraded"] is True
                assert entry["degradation_reason"] == "model_invalid_response"
        if key == "E":
            assert len(analysis["summary"]["degraded_ranges"]) == 1


if __name__ == "__main__":
    validate()
    print("Wiki stage 0: 8 synthetic samples, 32 analysis documents, citations and relations valid")
