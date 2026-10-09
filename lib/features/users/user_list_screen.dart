// lib/features/users/user_list_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../core/api_client.dart';
import '../auth/auth_controller.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_dialog.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_widgets.dart';
import '../../widgets/paged_footer_mixin.dart';
import '../../widgets/paged_list_view.dart';
import 'user_form.dart';
import 'user_repository.dart';

class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});
  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen>
    with PagedFooterMixin<UserListScreen> {
  int _reload = 0;

  void _refresh() => setState(() {
    _reload++;
    resetFooter();
  });

  Future<void> _add() async {
    final saved = await showUserForm(context);
    if (saved == true) {
      _snack('User created');
      _refresh();
    }
  }

  Future<void> _edit(UserRow u) async {
    final saved = await showUserForm(context, userId: u.id);
    if (saved == true) {
      // Editing yourself? Pick up the new name / profile photo.
      if (u.id == ref.read(authControllerProvider).user?.id) {
        ref.read(authControllerProvider.notifier).refreshProfile();
      }
      _snack('User updated');
      _refresh();
    }
  }

  Future<void> _delete(UserRow u) async {
    // Matches web's SweetAlert2 delete confirmation (user/list.blade.php):
    // title "Delete User?", text "This action cannot be undone.",
    // confirm "Yes, Delete" in #dc3545, cancel in #6c757d.
    final ok = await showHsConfirmDialog(context, title: 'Delete User?');
    if (!ok) return;
    try {
      await ref.read(userRepositoryProvider).delete(u.id);
      _snack('User deleted');
      _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(userRepositoryProvider);
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: HsAppBar(
        title: 'User Management',
        actions: [
          IconButton(
            tooltip: 'Add User',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _add,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add User'),
      ),
      body: Column(
        children: [
          Expanded(
            child: PagedListView<UserRow>(
              key: ValueKey(_reload),
              searchHint: 'Search by name, email or role…',
              fetchPage: repo.list,
              onPageLoaded: trackPage,
              itemBuilder: (context, u) => HsListCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Hs.teal,
                    // Cached between scrolls/refreshes instead of
                    // re-downloading every photo each time this list loads.
                    backgroundImage: u.image != null
                        ? CachedNetworkImageProvider(u.image!)
                        : null,
                    child: u.image != null
                        ? null
                        : Text(
                            u.name.isEmpty ? '?' : u.name[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(u.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Hs.ink)),
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined,
                        size: 20, color: Hs.blue),
                    onPressed: () => _edit(u),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Hs.red),
                    onPressed: () => _delete(u),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Order mirrors web's `.user-card` (user/list.blade.php
              // renderCards): Name [title], Email, Role, Image [avatar
              // above], Action [icons above].
              HsRow('Email', u.email, bottomDivider: true),
              HsRow(
                'Role',
                u.roleLabel,
                valueWidget: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      // Web `.badge-admin`/`.badge-user`: solid bg + white text.
                      color: u.isAdmin ? Hs.red : const Color(0xFF6C757D),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      u.roleLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
          ),
          if (footerTotal > 0) footerBar(),
        ],
      ),
    );
  }
}
