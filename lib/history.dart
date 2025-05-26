import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:forditva/db/database.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  void initState() {
    super.initState();
    _db = AppDatabase();
    _loadHistory();
  }

  void _loadHistory() {
    _translationsFuture = _db.translationDao.getAll();
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  Future<void> _deleteEntry(int id) async {
    await _db.translationDao.deleteEntry(id); // add this DAO method
    _loadHistory();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      backgroundColor: textGrey,
      body: FutureBuilder<List<Translation>>(
        future: _translationsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('No history'));
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final entry = list[i];
                return Container(
                  margin: const EdgeInsets.only(
                    bottom: 12,
                  ), // spacing between cards
                  child: Slidable(
                    key: ValueKey(entry.id),

                    // delete action on swipe:
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
                          label: 'Delete',
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12), // same 12px
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

                          // favorite toggle
                          IconButton(
                            icon: Icon(
                              entry.isFavorite ? Icons.star : Icons.star_border,
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
            ),
          );
        },
      ),
    );
  }
}
