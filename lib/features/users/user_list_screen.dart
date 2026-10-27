// lib/features/users/user_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../core/api_client.dart';
import '../auth/auth_controller.dart';
import '../../widgets/fallback_network_image.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_dialog.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_widgets.dart';
import '../../widgets/paged_footer_mixin.dart';
import '../../widgets/paged_list_view.dart';
import '../../widgets/phone_link.dart';
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
              searchHint: 'Search by name, mobile, email or role…',
              // Bottom clearance for the "Add User" FAB, which otherwise
              // sits on top of the last card.
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
              fetchPage: repo.list,
              onPageLoaded: trackPage,
              itemBuilder: (context, u) => _UserCard(
                user: u,
                onEdit: () => _edit(u),
                onDelete: () => _delete(u),
              ),
            ),
          ),
          if (footerTotal > 0) footerBar(),
        ],
      ),
    );
  }
}

/// One user: avatar, name + role chip, contact lines, and edit / delete.
/// The whole card opens the editor; the buttons are the explicit shortcuts.
class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });

  final UserRow user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final u = user;
    return HsListCard(
      accent: u.isAdmin ? Hs.secondary : Hs.blue,
      onTap: onEdit,
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(user: u),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.name.isEmpty ? '—' : u.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15.5,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Hs.ink)),
                    const SizedBox(height: 6),
                    _RoleChip(isAdmin: u.isAdmin, label: u.roleLabel),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                tooltip: 'Edit',
                icon: Icons.edit_outlined,
                color: Hs.blue,
                onPressed: onEdit,
              ),
              const SizedBox(width: 6),
              _ActionButton(
                tooltip: 'Delete',
                icon: Icons.delete_outline,
                color: Hs.red,
                onPressed: onDelete,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 10, right: 4),
            child: Divider(height: 1, thickness: 1, color: Hs.hairline),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ContactLine(
                  icon: Icons.phone_outlined,
                  child: u.mobile.isEmpty
                      ? const Text('No mobile number',
                          style: TextStyle(fontSize: 13.5, color: Hs.faint))
                      : PhoneLink(
                          u.mobile,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Hs.ink),
                        ),
                ),
                if (u.email.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ContactLine(
                    icon: Icons.mail_outline,
                    child: Text(u.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, color: Hs.inkSoft)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Profile photo over an initials disc: the initials show while the photo
/// loads and stay if it never does (users created on the web may have no
/// photo file on the server).
class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});
  final UserRow user;

  static const _size = 52.0;

  String get _initials {
    String first(String s) => s.trim().isEmpty ? '' : s.trim()[0].toUpperCase();
    final i = first(user.firstName) + first(user.lastName);
    return i.isEmpty ? '?' : i;
  }

  @override
  Widget build(BuildContext context) {
    final color = Hs.tileAccents[user.id % Hs.tileAccents.length];
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: color.withValues(alpha: .25), width: 2),
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(_initials,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
            if (user.image != null)
              // Cached between scrolls/refreshes instead of re-downloading
              // every photo each time this list loads.
              FallbackNetworkImage(
                urls: [user.image!],
                fallback: const SizedBox.shrink(),
                memCacheWidth: 160,
              ),
          ],
        ),
      ),
    );
  }
}

/// "Admin" / "User" pill: a tinted background with matching text, rather than
/// the web's solid block, so a screen of cards doesn't shout.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.isAdmin, required this.label});
  final bool isAdmin;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = isAdmin ? Hs.red : Hs.muted;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAdmin ? Icons.shield_outlined : Icons.person_outline,
              size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// A small icon + value line (phone, email) inside a card.
class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.child});
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: Hs.faint),
        const SizedBox(width: 10),
        Expanded(child: Align(alignment: Alignment.centerLeft, child: child)),
      ],
    );
  }
}

/// A 36px tinted square button for a card's edit / delete.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Hs.radiusSm),
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 19, color: color),
          ),
        ),
      ),
    );
  }
}
