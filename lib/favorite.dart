import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:forditva/db/database.dart'; // adjust path if needed
import 'package:google_fonts/google_fonts.dart';

const Color textGrey = Color(0xFF898888);
const Color navGreen = Color(0xFF436F4D);
const Color gold = Colors.amber;

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  _FavoritePageState createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  late final AppDatabase _db;
  late Future<List<Translation>> _favoritesFuture;
  late TextEditingController _searchController;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _db = AppDatabase();
    _searchController = TextEditingController();
    _loadFavorites();
  }

  void _loadFavorites() {
    _favoritesFuture = _db.translationDao.getAll().then(
      (all) => all.where((e) => e.isFavorite).toList(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: textGrey,
      appBar: AppBar(title: Text(loc.favorites)), // ← localized title
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
                hintText: loc.searchFavorites, // ← localized hint
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
              future: _favoritesFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allFavorites = snap.data ?? [];
                final filtered =
                    allFavorites.where((entry) {
                      final input = entry.input.toLowerCase();
                      final output = entry.output.toLowerCase();
                      return _searchQuery.isEmpty ||
                          input.contains(_searchQuery) ||
                          output.contains(_searchQuery);
                    }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      loc.noFavoritesFound, // ← localized message
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
                          // Texts
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

                          // Unfavorite star
                          IconButton(
                            icon: const Icon(Icons.star, color: gold, size: 24),
                            onPressed: () async {
                              await _db.translationDao.toggleFavorite(
                                entry.id,
                                false,
                              );
                              setState(_loadFavorites);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    loc.removedFromFavorites,
                                  ), // ← localized
                                ),
                              );
                            },
                          ),
                        ],
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
