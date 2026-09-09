import 'package:flutter/material.dart';

import '../providers/providers.dart';

class PagedTable extends StatelessWidget {
  const PagedTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.query,
    required this.onQuery,
    required this.total,
  });
  final List<String> columns;
  final List<DataRow> rows;
  final TableQuery query;
  final ValueChanged<TableQuery> onQuery;
  final int total;
  @override
  Widget build(BuildContext context) {
    final pages = query.pageSize == 0
            ? 1
            : (total / query.pageSize).ceil().clamp(1, 999999),
        page = query.page.clamp(0, pages - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            sortColumnIndex: query.sort,
            sortAscending: query.ascending,
            columns: columns.indexed
                .map(
                  (e) => DataColumn(
                    label: Text(e.$2),
                    onSort: (i, asc) =>
                        onQuery(query.copyWith(sort: i, ascending: asc)),
                  ),
                )
                .toList(),
            rows: rows,
          ),
        ),
        if (total == 0)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No records match the current filter.'),
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('$total records', style: const TextStyle(fontSize: 12)),
            DropdownButton<int>(
              value: query.pageSize,
              items: [10, 15, 20, 50, 0]
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s == 0 ? 'Show All' : 'Show $s'),
                    ),
                  )
                  .toList(),
              onChanged: (s) => onQuery(query.copyWith(pageSize: s, page: 0)),
            ),
            TextButton(
              onPressed: page > 0
                  ? () => onQuery(query.copyWith(page: page - 1))
                  : null,
              child: const Text('Previous'),
            ),
            Text('${page + 1} / $pages'),
            TextButton(
              onPressed: page < pages - 1
                  ? () => onQuery(query.copyWith(page: page + 1))
                  : null,
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}

List<T> pageItems<T>(List<T> rows, TableQuery q) {
  if (q.pageSize == 0) return rows;
  final pages = (rows.length / q.pageSize).ceil().clamp(1, 999999),
      page = q.page.clamp(0, pages - 1);
  return rows.skip(page * q.pageSize).take(q.pageSize).toList();
}
