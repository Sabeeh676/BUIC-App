import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:buic_app/home_page/add_project.dart';
import 'package:buic_app/home_page/project_detail_page.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, Map<String, dynamic>> _userCache = {};

  Future<Map<String, dynamic>> _fetchUserDetails(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      DocumentSnapshot studentDoc = await _firestore
          .collection('students')
          .doc(userId)
          .get();
      if (studentDoc.exists) {
        final data = {
          'name': studentDoc['name'] ?? 'Unknown Student',
          'profileImageUrl': studentDoc['profileImageUrl'],
        };
        if (mounted) _userCache[userId] = data;
        return data;
      }

      DocumentSnapshot teacherDoc = await _firestore
          .collection('teachers')
          .doc(userId)
          .get();
      if (teacherDoc.exists) {
        final data = {
          'name': teacherDoc['name'] ?? 'Unknown Teacher',
          'profileImageUrl': teacherDoc['profileImageUrl'],
        };
        if (mounted) _userCache[userId] = data;
        return data;
      }
    } catch (e) {
      // Handle potential errors, e.g., network issues
      print("Error fetching user details: $e");
    }

    return {'name': 'Unknown User', 'profileImageUrl': null};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Project Showcase',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('projects')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeletonLoader();
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Something went wrong: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.palette_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No projects yet.',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to showcase your work!',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final project = snapshot.data!.docs[index];
              return _buildProjectCard(project);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddProject()),
        ),
        label: const Text('Add Project'),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildProjectCard(DocumentSnapshot project) {
    final projectData = project.data() as Map<String, dynamic>;
    final ownerId = projectData['ownerId'];

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchUserDetails(ownerId),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting &&
            !_userCache.containsKey(ownerId)) {
          return _buildSkeletonCard();
        }
        // Show cached data immediately or if future resolves with no data
        final userData =
            userSnapshot.data ??
            _userCache[ownerId] ??
            {'name': 'Loading...', 'profileImageUrl': null};

        final imageUrls =
            (projectData['imageUrls'] as List?)?.cast<String>() ?? [];
        final reactions =
            (projectData['reactions'] as Map<String, dynamic>?) ?? {};
        final totalReactions = reactions.values.fold<int>(
          0,
          (sum, item) => sum + (item as int),
        );
        final createdAt = (projectData['createdAt'] as Timestamp?)?.toDate();

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectDetailPage(project: project),
            ),
          ),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.1),
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(userData, createdAt),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projectData['title'] ?? 'No Title',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        projectData['description'] ?? 'No Description',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (imageUrls.isNotEmpty)
                  _buildProjectImage(imageUrls.first, imageUrls.length),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildTags(projectData['tags']),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildCardFooter(reactions, totalReactions, project),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardHeader(Map<String, dynamic> userData, DateTime? createdAt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: userData['profileImageUrl'] != null
                ? NetworkImage(userData['profileImageUrl'])
                : null,
            child: userData['profileImageUrl'] == null
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userData['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (createdAt != null)
                  Text(
                    timeago.format(createdAt),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectImage(String imageUrl, int imageCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.broken_image,
                  color: Colors.grey[400],
                  size: 48,
                ),
              ),
            ),
          ),
          if (imageCount > 1)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.photo_library,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+${imageCount - 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTags(List<dynamic>? tags) {
    if (tags == null || tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: tags
          .take(4)
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tag.toString(),
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCardFooter(
    Map<String, dynamic> reactions,
    int totalReactions,
    DocumentSnapshot project,
  ) {
    // Sort reactions by count
    final sortedReactions = reactions.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (totalReactions > 0)
                Stack(
                  children: sortedReactions
                      .take(3)
                      .toList()
                      .asMap()
                      .entries
                      .map(
                        (entry) => Padding(
                          padding: EdgeInsets.only(left: entry.key * 15.0),
                          child: _buildReactionIcon(entry.value.key, size: 22),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(width: 8),
              if (totalReactions > 0)
                Text(
                  '$totalReactions reaction${totalReactions > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
            ],
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProjectDetailPage(project: project),
              ),
            ),
            child: Row(
              children: [
                const Text('Discuss'),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionIcon(String reaction, {double size = 24}) {
    IconData iconData;
    Color color;
    switch (reaction) {
      case 'insightful':
        iconData = Icons.lightbulb_outline;
        color = Colors.amber;
        break;
      case 'innovative':
        iconData = Icons.star_border;
        color = Colors.blue;
        break;
      case 'wellExecuted':
        iconData = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case 'love':
        iconData = Icons.favorite_border;
        color = Colors.red;
        break;
      default:
        iconData = Icons.circle;
        color = Colors.grey;
    }
    return CircleAvatar(
      radius: size / 2 + 2,
      backgroundColor: Colors.white,
      child: Icon(iconData, color: color, size: size),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      itemBuilder: (context, index) => _buildSkeletonCard(),
    );
  }

  Widget _buildSkeletonCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 22),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 120, height: 16, color: Colors.white),
                      const SizedBox(height: 4),
                      Container(width: 80, height: 12, color: Colors.white),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 24,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 16,
                color: Colors.white,
              ),
              const SizedBox(height: 4),
              Container(width: 200, height: 16, color: Colors.white),
              const SizedBox(height: 16),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: List.generate(
                  3,
                  (index) => Container(
                    width: 70,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
