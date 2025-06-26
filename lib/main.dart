import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Celebrity Browser',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(),
    );
  }
}

class Celebrity {
  final int id;
  final String name;
  final String? profilePath;
  final double popularity;

  Celebrity({
    required this.id,
    required this.name,
    this.profilePath,
    required this.popularity,
  });

  factory Celebrity.fromJson(Map<String, dynamic> json) {
    return Celebrity(
      id: json['id'],
      name: json['name'],
      profilePath: json['profile_path'],
      popularity: json['popularity']?.toDouble() ?? 0.0,
    );
  }
}

class CelebrityDetail {
  final int id;
  final String name;
  final String? biography;
  final String? birthday;
  final String? placeOfBirth;
  final String? profilePath;
  final double popularity;

  CelebrityDetail({
    required this.id,
    required this.name,
    this.biography,
    this.birthday,
    this.placeOfBirth,
    this.profilePath,
    required this.popularity,
  });

  factory CelebrityDetail.fromJson(Map<String, dynamic> json) {
    return CelebrityDetail(
      id: json['id'],
      name: json['name'],
      biography: json['biography'],
      birthday: json['birthday'],
      placeOfBirth: json['place_of_birth'],
      profilePath: json['profile_path'],
      popularity: json['popularity']?.toDouble() ?? 0.0,
    );
  }
}

class CelebrityImage {
  final String filePath;
  final double aspectRatio;

  CelebrityImage({
    required this.filePath,
    required this.aspectRatio,
  });

  factory CelebrityImage.fromJson(Map<String, dynamic> json) {
    return CelebrityImage(
      filePath: json['file_path'],
      aspectRatio: json['aspect_ratio']?.toDouble() ?? 1.0,
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String apiKey = '2dfe23358236069710a379edd4c65a6b';
  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  List<Celebrity> celebrities = [];
  Set<int> favorites = {};
  int currentPage = 1;
  bool isLoading = false;
  bool hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadCelebrities();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList('favorites') ?? [];
    setState(() {
      favorites = favoriteIds.map((id) => int.parse(id)).toSet();
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = favorites.map((id) => id.toString()).toList();
    await prefs.setStringList('favorites', favoriteIds);
  }

  Future<void> _loadCelebrities({bool loadMore = false}) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/person/popular?api_key=$apiKey&page=$currentPage'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Celebrity> newCelebrities = (data['results'] as List)
            .map((json) => Celebrity.fromJson(json))
            .toList();

        setState(() {
          if (loadMore) {
            celebrities.addAll(newCelebrities);
          } else {
            celebrities = newCelebrities;
          }
          hasMore = currentPage < data['total_pages'];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading celebrities: $e')),
      );
    }
  }

  void _toggleFavorite(int celebrityId) {
    setState(() {
      if (favorites.contains(celebrityId)) {
        favorites.remove(celebrityId);
      } else {
        favorites.add(celebrityId);
      }
    });
    _saveFavorites();
  }

  void _loadMore() {
    if (hasMore && !isLoading) {
      currentPage++;
      _loadCelebrities(loadMore: true);
    }
  }

  void _showFavorites() {
    final favoriteCelebrities =
        celebrities.where((c) => favorites.contains(c.id)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Favorites',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Expanded(
              child: favoriteCelebrities.isEmpty
                  ? Center(child: Text('No favorites yet'))
                  : ListView.builder(
                      itemCount: favoriteCelebrities.length,
                      itemBuilder: (context, index) {
                        final celebrity = favoriteCelebrities[index];
                        return _buildCelebrityTile(celebrity);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCelebrityTile(Celebrity celebrity) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: celebrity.profilePath != null
            ? NetworkImage('$imageBaseUrl${celebrity.profilePath}')
            : null,
        child: celebrity.profilePath == null ? Icon(Icons.person) : null,
      ),
      title: Text(celebrity.name),
      subtitle: Text('Popularity: ${celebrity.popularity.toStringAsFixed(1)}'),
      trailing: IconButton(
        icon: Icon(
          favorites.contains(celebrity.id)
              ? Icons.favorite
              : Icons.favorite_border,
          color: favorites.contains(celebrity.id) ? Colors.red : null,
        ),
        onPressed: () => _toggleFavorite(celebrity.id),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CelebrityDetailScreen(celebrityId: celebrity.id),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Celebrities'),
        actions: [
          IconButton(
            icon: Icon(Icons.favorite),
            onPressed: _showFavorites,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          currentPage = 1;
          await _loadCelebrities();
        },
        child: ListView.builder(
          itemCount: celebrities.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == celebrities.length) {
              return Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: isLoading
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _loadMore,
                          child: Text('View More'),
                        ),
                ),
              );
            }
            return _buildCelebrityTile(celebrities[index]);
          },
        ),
      ),
    );
  }
}

class CelebrityDetailScreen extends StatefulWidget {
  final int celebrityId;

  CelebrityDetailScreen({required this.celebrityId});

  @override
  _CelebrityDetailScreenState createState() => _CelebrityDetailScreenState();
}

class _CelebrityDetailScreenState extends State<CelebrityDetailScreen> {
  static const String apiKey = '2dfe23358236069710a379edd4c65a6b';
  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  CelebrityDetail? celebrityDetail;
  List<CelebrityImage> images = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCelebrityData();
  }

  Future<void> _loadCelebrityData() async {
    try {
      final detailResponse = await http.get(
        Uri.parse('$baseUrl/person/${widget.celebrityId}?api_key=$apiKey'),
      );

      final imagesResponse = await http.get(
        Uri.parse(
            '$baseUrl/person/${widget.celebrityId}/images?api_key=$apiKey'),
      );

      if (detailResponse.statusCode == 200 &&
          imagesResponse.statusCode == 200) {
        final detailData = json.decode(detailResponse.body);
        final imagesData = json.decode(imagesResponse.body);

        setState(() {
          celebrityDetail = CelebrityDetail.fromJson(detailData);
          images = (imagesData['profiles'] as List)
              .map((json) => CelebrityImage.fromJson(json))
              .toList();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading celebrity data: $e')),
      );
    }
  }

  Future<void> _downloadImage(String imagePath) async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage permission denied')),
        );
        return;
      }

      final response = await http.get(
        Uri.parse('$imageBaseUrl$imagePath'),
      );

      if (response.statusCode == 200) {
        final directory = await getExternalStorageDirectory();
        final fileName = imagePath.split('/').last;
        final file = File('${directory!.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image downloaded successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading image: $e')),
      );
    }
  }

  void _openImageGallery(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageGalleryScreen(
          images: images,
          initialIndex: initialIndex,
          onDownload: _downloadImage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Loading...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (celebrityDetail == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Error')),
        body: Center(child: Text('Failed to load celebrity data')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(celebrityDetail!.name),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (celebrityDetail!.profilePath != null)
              Center(
                child: CircleAvatar(
                  radius: 80,
                  backgroundImage: NetworkImage(
                    '$imageBaseUrl${celebrityDetail!.profilePath}',
                  ),
                ),
              ),
            SizedBox(height: 16),
            Text(
              celebrityDetail!.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 8),
            if (celebrityDetail!.birthday != null)
              Text('Birthday: ${celebrityDetail!.birthday}'),
            if (celebrityDetail!.placeOfBirth != null)
              Text('Place of Birth: ${celebrityDetail!.placeOfBirth}'),
            Text(
                'Popularity: ${celebrityDetail!.popularity.toStringAsFixed(1)}'),
            SizedBox(height: 16),
            if (celebrityDetail!.biography != null &&
                celebrityDetail!.biography!.isNotEmpty) ...[
              Text(
                'Biography',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: 8),
              Text(celebrityDetail!.biography!),
              SizedBox(height: 16),
            ],
            if (images.isNotEmpty) ...[
              Text(
                'Images',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _openImageGallery(index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '$imageBaseUrl${images[index].filePath}',
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ImageGalleryScreen extends StatelessWidget {
  final List<CelebrityImage> images;
  final int initialIndex;
  final Function(String) onDownload;

  ImageGalleryScreen({
    required this.images,
    required this.initialIndex,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: Colors.white),
            onPressed: () {
              final currentImage = images[initialIndex];
              onDownload(currentImage.filePath);
            },
          ),
        ],
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(
              'https://image.tmdb.org/t/p/original${images[index].filePath}',
            ),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 2,
          );
        },
        itemCount: images.length,
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            value: event == null
                ? 0
                : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
          ),
        ),
        pageController: PageController(initialPage: initialIndex),
      ),
    );
  }
}
