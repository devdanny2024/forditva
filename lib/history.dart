import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:forditva/db/database.dart';
import 'package:google_fonts/google_fonts.dart';

import 'flutter_gen/gen_l10n/app_localizations.dart';

const Color textGrey = Color(0xFF898888);
const Color navGreen = Color(0xFF436F4D);
const Color gold = Colors.amber;

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final AppDatabase _db;
  late Future<List<Translation>> _translationsFuture;
  late TextEditingController _searchController;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _db = AppDatabase();
    _searchController = TextEditingController();
    _loadHistory();
  }

  void _loadHistory() {
    _translationsFuture = _db.translationDao.getAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _db.close();
    super.dispose();
  }

  Future<void> _deleteEntry(int id) async {
    await _db.translationDao.deleteEntry(id);
    _loadHistory();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.history)), // ← localized
      backgroundColor: textGrey,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: loc.searchHistory, // ← localized
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Translation>>(
              future: _translationsFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = snap.data ?? [];
                final filtered =
                    list.where((entry) {
                      final input = entry.input.toLowerCase();
                      final output = entry.output.toLowerCase();
                      return _searchQuery.isEmpty ||
                          input.contains(_searchQuery) ||
                          output.contains(_searchQuery);
                    }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      loc.noHistoryFound, // ← localized
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final entry = filtered[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Slidable(
                        key: ValueKey(entry.id),
                        endActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          dismissible: DismissiblePane(
                            onDismissed: () => _deleteEntry(entry.id),
                          ),
                          children: [
                            SlidableAction(
                              onPressed: (_) => _deleteEntry(entry.id),
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              icon: Icons.delete,
                              label: loc.delete, // ← localized
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.input,
                                      style: GoogleFonts.robotoCondensed(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: navGreen,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      entry.output,
                                      style: GoogleFonts.robotoCondensed(
                                        fontSize: 14,
                                        color: Colors.black,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  entry.isFavorite
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: entry.isFavorite ? gold : Colors.grey,
                                ),
                                onPressed: () async {
                                  await _db.translationDao.toggleFavorite(
                                    entry.id,
                                    !entry.isFavorite,
                                  );
                                  _loadHistory();
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
