# Recommendations Database Summary

## Overview

Created: 2025-12-26

A lightweight, optimized SQLite database containing only the top-ranked podcasts from Apple Podcasts, designed for fast recommendation queries.

---

## Database Statistics

### File Size
- **Original Database:** 4,753.34 MB
- **Recommendations Database:** 3.66 MB
- **Size Reduction:** 4,749.68 MB (99.9% smaller)

### Data Counts

| Table | Row Count | Description |
|-------|-----------|-------------|
| **podcasts** | 2,319 | Only podcasts with Apple rankings |
| **categories** | 107 | All subcategories |
| **parent_categories** | 22 | All parent categories |
| **parent_category_subcategories** | 108 | Category hierarchy links |
| **podcast_category_ranks** | 4,201 | All ranking entries |

---

## Schema

### podcasts
Contains 2,319 top-ranked podcasts (filtered from 4.5M+ total)
- All standard podcast metadata (title, description, author, etc.)
- `appleTopRank` - Overall Apple Podcasts rank (1-200)
- `itunesId` - Apple's iTunes identifier

### podcast_category_ranks
4,201 category ranking entries (composite primary key)
- `podcast_id` - Foreign key to podcasts.id
- `genre_id` - Apple's genre or subgenre ID
- `rank` - Rank position (1-30 or 1-200)

**Indexes:**
- `idx_podcast_category_ranks_genre` on (genre_id, rank) - Fast category lookups
- `idx_podcast_category_ranks_podcast` on (podcast_id) - Fast podcast lookups

### categories
107 subcategories with Apple subgenre IDs
- `subgenre_id` - Apple's subgenre identifier
- `label` - Category name

### parent_categories
22 parent categories with Apple genre IDs
- `genre_id` - Apple's genre identifier
- `label` - Parent category name

### parent_category_subcategories
108 hierarchical relationships between parents and subcategories

---

## Data Source

Rankings fetched from Apple Podcasts on 2025-12-26:
- **52 categories** (16 parent + 36 subcategories)
- **30 podcasts per category** (top-ranked)
- **Randomized rate limiting:** 2000-9000ms between requests

---

## Use Cases

This database is optimized for:

1. **Category-based recommendations**
   - "Top 10 Buddhism podcasts"
   - "Top Design podcasts"

2. **Cross-category analysis**
   - Podcasts ranked in multiple categories
   - Broad vs. niche appeal

3. **High-quality podcast filtering**
   - Only includes podcasts that made Apple's top charts
   - Pre-filtered quality signal

4. **Fast queries**
   - 99.9% smaller than original database
   - Indexed for category and podcast lookups
   - No JSON parsing needed

---

## Example Queries

### Top 10 podcasts in a specific category

```sql
SELECT p.title, pcr.rank
FROM podcasts p
JOIN podcast_category_ranks pcr ON p.id = pcr.podcast_id
WHERE pcr.genre_id = 1438  -- Buddhism
ORDER BY pcr.rank
LIMIT 10
```

### Podcasts ranked in multiple categories

```sql
SELECT p.title, COUNT(pcr.genre_id) as category_count
FROM podcasts p
JOIN podcast_category_ranks pcr ON p.id = pcr.podcast_id
GROUP BY p.id, p.title
ORDER BY COUNT(pcr.genre_id) DESC
LIMIT 10
```

### Top podcasts with category metadata

```sql
SELECT pcr.rank, p.title, c.label as category, pc.label as parent_category
FROM podcast_category_ranks pcr
JOIN podcasts p ON pcr.podcast_id = p.id
JOIN categories c ON pcr.genre_id = c.subgenre_id
LEFT JOIN parent_category_subcategories pcs ON c.id = pcs.subcategory_id
LEFT JOIN parent_categories pc ON pcs.parent_category_id = pc.id
WHERE pcr.genre_id = 1402  -- Design
ORDER BY pcr.rank
LIMIT 10
```

---

## Notable Findings

### Most Cross-Category Podcast
**The Shawn Ryan Show** - Ranked in 28 different categories
- #1 in Culture (1324)
- #1 in Philosophy (1443)
- Ranked in 26 other categories

### Category Coverage Examples

**Buddhism (1438):**
- 30 podcasts
- Top: Tara Brach (#1)

**Design (1402):**
- 30 podcasts
- Top: 99% Invisible (#1)
- 99% Invisible also ranked #147 overall in Apple Podcasts

---

## File Location

- **Database File:** `/Users/erandrorsmacbookpro/Outcast-AI/Data/recommendations.sqlite`
- **Original Database:** `/Users/erandrorsmacbookpro/Outcast-AI/Data/podcastindex_feeds.db` (unchanged)

---

## Maintenance

**To update rankings:**
1. Run `fetch_all_category_rankings.py` on original database
2. Run `migrate_rankings_to_table.py` on original database
3. Re-run `create_recommendations_db.py` to refresh recommendations.sqlite

**Recommended update frequency:** Weekly or monthly to keep rankings current
