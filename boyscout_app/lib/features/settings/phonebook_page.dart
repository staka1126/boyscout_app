import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/providers/app_state_provider.dart';

class _Contact {
  final String name;
  final String? phone;
  final String? email;
  final String type; // 'leader' | 'guardian' | 'committee'

  const _Contact({
    required this.name,
    this.phone,
    this.email,
    required this.type,
  });

  String get typeLabel {
    switch (type) {
      case 'leader':    return 'リーダー';
      case 'guardian':  return '保護者';
      case 'committee': return '団委員';
      default:          return '';
    }
  }
}

final _phonebookProvider = FutureProvider<List<_Contact>>((ref) async {
  final troopId = ref.watch(currentTroopIdProvider);
  if (troopId == null) return [];

  final users      = await ref.read(userRepositoryProvider).getByTroop(troopId);
  final guardians  = await ref.read(guardianRepositoryProvider).getAll();
  final committees = await ref.read(committeeRepositoryProvider).getByTroop(troopId);

  final contacts = <_Contact>[
    for (final u in users)
      _Contact(name: u.name, phone: u.phone, email: u.email, type: 'leader'),
    for (final g in guardians)
      _Contact(name: g.name, phone: g.phone, email: g.email, type: 'guardian'),
    for (final c in committees)
      _Contact(name: c.name, phone: c.phone, email: c.email, type: 'committee'),
  ];

  // 電話番号またはメールを持つ人のみ、名前昇順
  contacts.sort((a, b) => a.name.compareTo(b.name));
  return contacts;
});

class PhonebookPage extends ConsumerStatefulWidget {
  const PhonebookPage({super.key});

  @override
  ConsumerState<PhonebookPage> createState() => _PhonebookPageState();
}

class _PhonebookPageState extends ConsumerState<PhonebookPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_phonebookProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('電話帳')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: '氏名で検索',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('エラー: $e')),
          data: (contacts) {
            final filtered = _query.isEmpty
                ? contacts
                : contacts.where((c) => c.name.contains(_query)).toList();

            if (filtered.isEmpty) {
              return const Center(
                  child: Text('該当する連絡先がありません',
                      style: TextStyle(color: Colors.grey)));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _ContactCard(contact: filtered[i]),
            );
          },
        )),
      ]),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final _Contact contact;
  const _ContactCard({required this.contact});

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(uri);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('電話アプリを起動できませんでした')));
      }
    }
  }

  Future<void> _mail(BuildContext context, String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    try {
      await launchUrl(uri);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('メールアプリを起動できませんでした')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasPhone = contact.phone != null && contact.phone!.isNotEmpty;
    final hasEmail = contact.email != null && contact.email!.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Text(
              contact.name.isNotEmpty ? contact.name[0] : '?',
              style: TextStyle(fontWeight: FontWeight.w700,
                  color: cs.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contact.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(contact.typeLabel,
                      style: TextStyle(fontSize: 10, color: cs.onSecondaryContainer)),
                ),
                if (hasPhone) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.phone_outlined, size: 12, color: cs.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(contact.phone!,
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ]),
            ],
          )),
          // アクションボタン
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (hasPhone)
              IconButton(
                icon: const Icon(Icons.phone),
                color: const Color(0xFF43A047),
                onPressed: () => _call(context, contact.phone!),
                tooltip: '電話をかける',
              ),
            if (hasEmail)
              IconButton(
                icon: const Icon(Icons.email_outlined),
                color: cs.primary,
                onPressed: () => _mail(context, contact.email!),
                tooltip: 'メールを送る',
              ),
          ]),
        ]),
      ),
    );
  }
}
