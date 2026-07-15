import 'package:buic_app/home_page/image_grid.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class ProjectDetailPage extends StatefulWidget {
  final DocumentSnapshot project;

  const ProjectDetailPage({super.key, required this.project});

  @override
  State<ProjectDetailPage> createState() => ProjectDetailPageState();
}

class ProjectDetailPageState extends State<ProjectDetailPage> {
  late Map<String, dynamic> _projectData;
  final _feedbackController = TextEditingController();
  String _feedbackType = 'Praise';

  @override
  void initState() {
    super.initState();
    _projectData = widget.project.data() as Map<String, dynamic>;
  }

  // ... (keep all other functions: _handleReaction, _postFeedback, etc.)
  Future<void> _handleReaction(String reactionType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = widget.project.reference;
    final userId = user.email!.split('@')[0];

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final currentReactions = Map<String, dynamic>.from(
        snapshot.get('reactions'),
      );
      final reactedBy = Map<String, dynamic>.from(
        snapshot.get('reactedBy') ?? {},
      );

      if (reactedBy[userId] == reactionType) {
        // User is retracting their reaction
        currentReactions[reactionType] =
            (currentReactions[reactionType] ?? 1) - 1;
        reactedBy.remove(userId);
      } else {
        // If user reacted with something else before, retract it first
        if (reactedBy.containsKey(userId)) {
          String oldReaction = reactedBy[userId];
          currentReactions[oldReaction] =
              (currentReactions[oldReaction] ?? 1) - 1;
        }
        // Add the new reaction
        currentReactions[reactionType] =
            (currentReactions[reactionType] ?? 0) + 1;
        reactedBy[userId] = reactionType;
      }

      transaction.update(docRef, {
        'reactions': currentReactions,
        'reactedBy': reactedBy,
      });

      setState(() {
        _projectData['reactions'] = currentReactions;
        _projectData['reactedBy'] = reactedBy;
      });
    });
  }

  Future<void> _postFeedback() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _feedbackController.text.trim().isEmpty) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('students')
        .doc(user.email!.split('@')[0])
        .get();

    String userName = userDoc.data()?['name'] ?? 'Anonymous';
    String? userProfilePic = userDoc.data()?['profileImageUrl'];

    await widget.project.reference.collection('feedback').add({
      'text': _feedbackController.text.trim(),
      'type': _feedbackType,
      'authorName': userName,
      'authorProfilePic': userProfilePic,
      'authorId': user.email!.split('@')[0],
      'createdAt': FieldValue.serverTimestamp(),
    });

    _feedbackController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls =
        (_projectData['imageUrls'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(_projectData['title'])),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrls.isNotEmpty) ImageGrid(imageUrls: imageUrls),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _projectData['title'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildOwnerInfo(),
                  const SizedBox(height: 16),
                  Text(_projectData['description']),
                  const SizedBox(height: 16),
                  _buildTags(),
                  const SizedBox(height: 16),
                  _buildLinks(),
                  const Divider(height: 32),
                  _buildReactions(),
                  const Divider(height: 32),
                  _buildFeedbackSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (keep all other build helpers: _buildOwnerInfo, _buildTags, etc.)
  Widget _buildOwnerInfo() {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: _projectData['ownerProfilePic'] != null
              ? NetworkImage(_projectData['ownerProfilePic'])
              : null,
          child: _projectData['ownerProfilePic'] == null
              ? const Icon(Icons.person)
              : null,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _projectData['ownerName'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Project Owner',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTags() {
    final tags = _projectData['tags'] as List<dynamic>?;
    if (tags == null || tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: tags.map((tag) => Chip(label: Text(tag.toString()))).toList(),
    );
  }

  Widget _buildLinks() {
    return Row(
      children: [
        if (_projectData['githubUrl'] != null &&
            _projectData['githubUrl'].isNotEmpty)
          ElevatedButton.icon(
            onPressed: () => _launchURL(_projectData['githubUrl']),
            icon: const Icon(Icons.code),
            label: const Text('GitHub'),
          ),
        const SizedBox(width: 8),
        if (_projectData['demoUrl'] != null &&
            _projectData['demoUrl'].isNotEmpty)
          ElevatedButton.icon(
            onPressed: () => _launchURL(_projectData['demoUrl']),
            icon: const Icon(Icons.public),
            label: const Text('Live Demo'),
          ),
      ],
    );
  }

  Widget _buildReactions() {
    final reactions = Map<String, int>.from(
      _projectData['reactions'].map((k, v) => MapEntry(k, v as int)),
    );
    final reactedBy = _projectData['reactedBy'] ?? {};
    final myReaction =
        reactedBy[FirebaseAuth.instance.currentUser?.email?.split('@')[0]];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reactions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _reactionChip(
              'insightful',
              '💡 Insightful',
              myReaction,
              reactions['insightful'] ?? 0,
            ),
            _reactionChip(
              'innovative',
              '🚀 Innovative',
              myReaction,
              reactions['innovative'] ?? 0,
            ),
            _reactionChip(
              'wellExecuted',
              '👏 Well-Executed',
              myReaction,
              reactions['wellExecuted'] ?? 0,
            ),
            _reactionChip(
              'love',
              '❤️ Love',
              myReaction,
              reactions['love'] ?? 0,
            ),
          ],
        ),
      ],
    );
  }

  Widget _reactionChip(
    String type,
    String label,
    String? myReaction,
    int count,
  ) {
    final isSelected = myReaction == type;
    return ActionChip(
      onPressed: () => _handleReaction(type),
      backgroundColor: isSelected ? Colors.teal.withOpacity(0.2) : null,
      label: Text('$label ($count)'),
    );
  }

  Widget _buildFeedbackSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Feedback',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildFeedbackInput(),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: widget.project.reference
              .collection('feedback')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                return _buildFeedbackTile(doc.data() as Map<String, dynamic>);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeedbackInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                hintText: 'Share your thoughts...',
                border: InputBorder.none,
              ),
              maxLines: 3,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: _feedbackType,
                  items: ['Praise', 'Question', 'Suggestion']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) => setState(() => _feedbackType = val!),
                ),
                ElevatedButton(
                  onPressed: _postFeedback,
                  child: const Text('Post'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackTile(Map<String, dynamic> data) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: data['authorProfilePic'] != null
            ? NetworkImage(data['authorProfilePic'])
            : null,
        child: data['authorProfilePic'] == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(data['authorName']),
      subtitle: Text(data['text']),
      trailing: Chip(label: Text(data['type'])),
    );
  }

  void _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }
}
