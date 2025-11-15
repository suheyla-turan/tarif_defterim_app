import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ad: ${user?.firstName ?? ''} ${user?.lastName ?? ''}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('E-posta: ${user?.email ?? '-'}'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
              child: const Text('Çıkış Yap'),
            ),
          ],
        ),
      ),
    );
  }
}


