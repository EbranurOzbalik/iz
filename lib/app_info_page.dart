import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'journal_store.dart';
import 'release_config.dart';
import 'tmdb_attribution.dart';

Future<void> openExternal(BuildContext context, Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // A missing browser or mail client must not interrupt the journal.
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Bağlantı açılamadı: $uri')));
}

class AppInfoPage extends StatefulWidget {
  const AppInfoPage({
    super.key,
    required this.store,
    this.config = const ReleaseConfig(),
  });
  final JournalStore store;
  final ReleaseConfig config;
  @override
  State<AppInfoPage> createState() => _AppInfoPageState();
}

class _AppInfoPageState extends State<AppInfoPage> {
  late final Future<PackageInfo?> package = PackageInfo.fromPlatform()
      .then<PackageInfo?>((value) => value)
      .catchError((_) => null);
  bool deleting = false;

  Future<void> clearJournal() async {
    if (deleting || widget.store.busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bütün izlerin silinsin mi?'),
        content: Text(
          '${widget.store.entries.length} eser, bütün notların, puanların ve '
          'takvim kayıtların bu cihazdan silinecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tümünü sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => deleting = true);
    var message = 'Günlüğündeki bütün kayıtlar silindi.';
    try {
      await widget.store.clear();
    } catch (_) {
      message = 'Kayıtlar silinemedi. Günlüğün korundu; tekrar deneyebilirsin.';
    }
    if (!mounted) return;
    setState(() => deleting = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yardım ve gizlilik')),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) => InfoBody(
          children: [
            Text('İZ', style: Theme.of(context).textTheme.headlineLarge),
            const Text('Hikâyeler geçer, izleri kalır.'),
            const SizedBox(height: 8),
            FutureBuilder<PackageInfo?>(
              future: package,
              builder: (context, snapshot) => snapshot.data == null
                  ? const SizedBox.shrink()
                  : Text(
                      'Sürüm ${snapshot.data!.version} '
                      '(${snapshot.data!.buildNumber})',
                    ),
            ),
            if (widget.config.developerName.trim().isNotEmpty)
              Text(widget.config.developerName.trim()),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Gizlilik politikası'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PrivacyPage(config: widget.config),
                ),
              ),
            ),
            if (widget.config.supportUri case final uri?)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline),
                title: const Text('Destek için yaz'),
                subtitle: Text(widget.config.supportEmail),
                onTap: () => openExternal(context, uri),
              ),
            const Divider(),
            const InfoSection(
              title: 'Nasıl kullanılır?',
              text:
                  'Eser ekle düğmesinden türü seçip adını yaz. Kitaplarda '
                  'Türkçe veya İngilizce baskıyı seçebilirsin. Film, dizi ve '
                  'tiyatroyu katalogda arayabilir veya elle ekleyebilirsin. Arşivinden bir eseri açarak '
                  'durumunu, puanını ve notunu güncelle.',
            ),
            const InfoSection(
              title: 'Takvim ne zaman renklenir?',
              text:
                  'Bir not, puan, durum veya ilerleme kaydı oluşturduğunda '
                  'o gün bir iz oluşur. Sadece arşive eser eklemek takvimi '
                  'renklendirmez. Aynı eserde aynı gün yaptığın aynı tür '
                  'güncellemeler tek iz olarak görünür.',
            ),
            const InfoSection(
              title: 'İnternet ve kayıtların',
              text:
                  'Arşivin ve notların cihazında saklanır. İnternet olmadan '
                  'günlüğünü düzenleyebilir ve elle eser ekleyebilirsin; katalog '
                  'aramaları ve kapakların yüklenmesi internet gerektirir. '
                  'Hesap veya bulut eşitleme yoktur. Uygulamayı silmeden önce '
                  'saklamak istediğin notları başka bir yere kopyala.',
            ),
            TextButton(
              onPressed: () =>
                  openExternal(context, Uri.https('openlibrary.org', '/about')),
              child: const Text('Kitap bilgileri: Open Library'),
            ),
            const MovieAttribution(),
            TextButton(
              onPressed: () =>
                  showLicensePage(context: context, applicationName: 'İZ'),
              child: const Text('Açık kaynak lisansları'),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed:
                  deleting || widget.store.busy || widget.store.entries.isEmpty
                  ? null
                  : clearJournal,
              icon: const Icon(Icons.delete_outline),
              label: Text(deleting ? 'Siliniyor…' : 'Tüm kayıtlarımı sil'),
            ),
          ],
        ),
      ),
    ),
  );
}

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key, this.config = const ReleaseConfig()});
  final ReleaseConfig config;
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  late final policy = rootBundle.loadString('assets/legal/privacy_tr.json');
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gizlilik politikası')),
    body: SafeArea(
      child: FutureBuilder<String>(
        future: policy,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Gizlilik metni açılamadı.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = jsonDecode(snapshot.data!) as Map<String, dynamic>;
          return InfoBody(
            children: [
              Text('Güncelleme: ${data['updated']}'),
              const SizedBox(height: 20),
              for (final section in data['sections'] as List)
                InfoSection(title: section['title'], text: section['text']),
              if (widget.config.developerName.isNotEmpty)
                Text('Geliştirici: ${widget.config.developerName}'),
              if (widget.config.supportUri case final uri?)
                TextButton(
                  onPressed: () => openExternal(context, uri),
                  child: Text(widget.config.supportEmail),
                ),
              if (widget.config.privacyUri case final uri?)
                TextButton(
                  onPressed: () => openExternal(context, uri),
                  child: const Text('Gizlilik politikasını webde aç'),
                ),
              TextButton(
                onPressed: () => openExternal(
                  context,
                  Uri.https('archive.org', '/about/terms.php'),
                ),
                child: const Text('Internet Archive gizlilik bilgileri'),
              ),
              TextButton(
                onPressed: () => openExternal(
                  context,
                  Uri.https(
                    'foundation.wikimedia.org',
                    '/wiki/Policy:Privacy_policy',
                  ),
                ),
                child: const Text('Wikimedia gizlilik bilgileri'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class InfoBody extends StatelessWidget {
  const InfoBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

class InfoSection extends StatelessWidget {
  const InfoSection({super.key, required this.title, required this.text});
  final String title, text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(text),
      ],
    ),
  );
}
