import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'theme.dart';
import 'models.dart';
import 'data_service.dart';

/// Ingrandisce una foto della galleria in un dialog scuro.
void showGalleryPhotoDialog(BuildContext context, ProfilePhoto photo) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: InteractiveViewer(
        child: Image.network(
          photo.url,
          fit: BoxFit.contain,
          errorBuilder: (context, _, __) => const Padding(
            padding: EdgeInsets.all(48),
            child: Icon(Icons.broken_image, color: textSecondary, size: 48),
          ),
        ),
      ),
    ),
  );
}

/// Sezione "La mia galleria" nel profilo: strip orizzontale con
/// aggiunta ed eliminazione delle proprie foto (bucket privato, RLS 0008).
class ProfileGallerySection extends StatefulWidget {
  final String profileId;

  const ProfileGallerySection({Key? key, required this.profileId})
      : super(key: key);

  @override
  State<ProfileGallerySection> createState() => _ProfileGallerySectionState();
}

class _ProfileGallerySectionState extends State<ProfileGallerySection> {
  List<ProfilePhoto> _photos = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final photos =
        await EcoraDataService.instance.fetchProfilePhotos(widget.profileId);
    if (!mounted) return;
    setState(() {
      _photos = photos;
      _loading = false;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addPhoto() async {
    if (_busy) return;
    if (_photos.length >= EcoraDataService.maxProfilePhotos) {
      _showSnack(
          "Limite di ${EcoraDataService.maxProfilePhotos} foto raggiunto.");
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    final bytes = await picked.readAsBytes();
    final error = await EcoraDataService.instance
        .uploadProfilePhoto(picked.name, bytes);
    if (!mounted) return;
    if (error != null) {
      setState(() => _busy = false);
      _showSnack(error);
      return;
    }
    await _reload();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _deletePhoto(ProfilePhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: slateSurface,
        title: const Text("Eliminare la foto?",
            style: TextStyle(color: textPrimary, fontSize: 16)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: textSecondary),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("ANNULLA"),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("ELIMINA"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final error =
        await EcoraDataService.instance.deleteProfilePhoto(photo.path);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error);
      return;
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "LA MIA GALLERIA (${_photos.length}/${EcoraDataService.maxProfilePhotos})",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 1.0,
            color: premiumGold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 76,
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: premiumGold),
                  ),
                )
              : ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _AddPhotoTile(busy: _busy, onTap: _addPhoto),
                    ..._photos.map((p) => _PhotoThumb(
                          photo: p,
                          onTap: () => showGalleryPhotoDialog(context, p),
                          onDelete: () => _deletePhoto(p),
                        )),
                  ],
                ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Vietati contenuti espliciti (policy Google Play): comportano la rimozione dell'account.",
          style: TextStyle(fontSize: 10, color: textSecondary, height: 1.3),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;

  const _AddPhotoTile({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: slateSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: premiumGold.withValues(alpha: 0.4)),
        ),
        child: busy
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: premiumGold),
                ),
              )
            : const Icon(Icons.add_photo_alternate,
                color: premiumGold, size: 26),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final ProfilePhoto photo;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _PhotoThumb(
      {required this.photo, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 72,
            height: 72,
            margin: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                photo.url,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => Container(
                  color: slateSurface,
                  child: const Icon(Icons.broken_image,
                      color: textSecondary, size: 20),
                ),
              ),
            ),
          ),
          if (onDelete != null)
            Positioned(
              top: 2,
              right: 10,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Strip di sola lettura della galleria di un utente, usata dal gestore
/// nella consolle di valutazione candidati. Con privacy 'ghost' le RLS
/// mostrano comunque la galleria all'host di un evento richiesto.
class CandidateGalleryStrip extends StatelessWidget {
  final String userId;

  const CandidateGalleryStrip({Key? key, required this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      height: 76,
      child: FutureBuilder<List<ProfilePhoto>>(
        future: EcoraDataService.instance.fetchProfilePhotos(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: premiumGold),
              ),
            );
          }
          final photos = snapshot.data ?? const [];
          if (photos.isEmpty) {
            return const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Nessuna foto nella galleria del profilo.",
                style: TextStyle(fontSize: 11, color: textSecondary),
              ),
            );
          }
          return ListView(
            scrollDirection: Axis.horizontal,
            children: photos
                .map((p) => _PhotoThumb(
                      photo: p,
                      onTap: () => showGalleryPhotoDialog(context, p),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}
