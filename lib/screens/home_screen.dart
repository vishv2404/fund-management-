import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fund_management_app/models/group_model.dart';
import 'package:fund_management_app/models/expense_model.dart';
import 'package:fund_management_app/screens/login_screen.dart';
import 'package:fund_management_app/screens/profile_screen.dart';
import 'package:fund_management_app/screens/create_group_screen.dart';
import 'package:fund_management_app/screens/update_profile_screen.dart';
import 'package:fund_management_app/screens/group_details_screen.dart';
import 'package:fund_management_app/screens/initial_contribution_screen.dart';
import 'package:fund_management_app/screens/top_up_screen.dart';
import 'package:fund_management_app/services/auth_service.dart';
import 'package:fund_management_app/services/group_service.dart';
import 'package:fund_management_app/utils/app_constants.dart';
import 'package:fund_management_app/utils/custom_colors.dart';
import 'package:fund_management_app/widgets/custom_button.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final GroupService _groupService = GroupService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  int _selectedIndex = 0;

  late final List<Widget> _widgetOptions;
  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      _buildHomeTabContent(),
      _buildHistoryTabContent(),
      const ProfileScreen(),
    ];
  }

  void _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'History';
      case 2:
        return 'My Profile';
      default:
        return AppConstants.appName;
    }
  }

  void _navigateToUpdateProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UpdateProfileScreen()),
    );
  }

  void _showToast(String message, Color backgroundColor) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: backgroundColor,
      textColor: AppColors.textLight,
      fontSize: 16.0,
    );
  }

  void _deleteGroup(String groupId, String groupName, String creatorUid) async {
    final String? currentUserUid = _firebaseAuth.currentUser?.uid;

    if (currentUserUid != creatorUid) {
      _showToast(
        'You are not the admin of this group and cannot delete it.',
        AppColors.errorRed,
      );
      return;
    }

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Confirm Deletion',
            style: TextStyle(color: AppColors.textDark),
          ),
          content: Text(
            'Are you sure you want to delete the group "$groupName"? This action cannot be undone.',
            style: TextStyle(color: AppColors.textDark.withOpacity(0.8)),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.hintGrey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: AppColors.errorRed),
              ),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      bool success = await _groupService.deleteGroup(groupId);
      if (success) {
        _showToast(
          'Group "$groupName" deleted successfully!',
          AppColors.successGreen,
        );
      }
    }
  }

  // Helper to get icon for category AND its color
  Map<String, dynamic> _getCategoryIconAndColor(String categoryName) {
    return AppConstants.groupCategories.firstWhere(
          (cat) => cat['name'] == categoryName,
      orElse: () => {
        'name': 'Other',
        'icon': Icons.category,
        'color': AppColors.hintGrey,
      },
        );
  }

  Widget _buildHomeTabContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'My Groups',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<GroupModel>>(
            stream: _groupService.getUsersGroups(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentGreen,
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.errorRed),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'No groups available yet. Please check back later or join an existing group.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.hintGrey, fontSize: 16),
                  ),
                );
              }

              List<GroupModel> groups = snapshot.data!;
              final String? currentLoggedInUserUid =
                  _firebaseAuth.currentUser?.uid;
              final String? currentLoggedInUserEmail =
                  _firebaseAuth.currentUser?.email;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  GroupModel group = groups[index];
                  bool isGroupAdmin =
                      currentLoggedInUserUid == group.creatorUid;

                  // Get current user's balance for this group
                  double currentUserBalance = 0.0;
                  if (currentLoggedInUserEmail != null) {
                    currentUserBalance =
                        group.memberBalances[currentLoggedInUserEmail] ?? 0.0;
                  }

                  // --- REVISED CONDITION FOR NAVIGATION (SIMPLIFIED AND MORE ROBUST) ---
                  // Check for initial contribution: If balance is 0 AND initial contribution is set to > 0
                  // Use a small epsilon for floating point comparison if exact 0.0 is too strict
                  bool needsInitialContribution =
                      (group.initialContributionAmount > 0 &&
                      currentUserBalance == 0.0);

                  // Check if current balance is below minimum threshold (only if initial is not needed/done)
                  bool isBelowMinimumBalance =
                      !needsInitialContribution &&
                      currentUserBalance < group.minimumBalanceThreshold;
                  // --- END REVISED CONDITION ---

                  final categoryData = _getCategoryIconAndColor(
                    group.groupCategory,
                  ); // Corrected method name

                  return Card(
                    margin: const EdgeInsets.only(bottom: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 3,
                    color: AppColors.cardBackground,
                    child: InkWell(
                      onTap: () async {
                        if (needsInitialContribution) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  InitialContributionScreen(group: group),
                            ),
                          );
                        } else if (isBelowMinimumBalance) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TopUpScreen(
                                group: group,
                                currentBalance: currentUserBalance,
                                minimumBalanceThreshold:
                                    group.minimumBalanceThreshold,
                              ),
                            ),
                          );
                        } else {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  GroupDetailsScreen(group: group),
                            ),
                          );
                        }
                        // Removed setState(() {}); from here. StreamBuilder should handle updates.
                      },
                      borderRadius: BorderRadius.circular(15),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Category Icon
                            Icon(
                              categoryData['icon'],
                              color: categoryData['color'],
                              size: 40,
                            ),
                            const SizedBox(width: 15),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.groupName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Created: ${group.createdAt.day}/${group.createdAt.month}/${group.createdAt.year}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.hintGrey.withOpacity(
                                        0.7,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Display User's Balance for the group
                                  Text(
                                    'My Balance: ₹${currentUserBalance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: currentUserBalance >= 0
                                          ? AppColors.successGreen
                                          : AppColors.errorRed,
                                    ),
                                  ),
                                  // Display reminders based on status
                                  if (needsInitialContribution)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        'Initial Pay Pending: ₹${group.initialContributionAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.errorRed,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  else if (isBelowMinimumBalance)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        'Below Min Balance! Add funds to ₹${group.minimumBalanceThreshold.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.errorRed,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  if (isBelowMinimumBalance) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.accentGreen,
                                          foregroundColor: AppColors.textDark,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => TopUpScreen(
                                                group: group,
                                                currentBalance:
                                                    currentUserBalance,
                                                minimumBalanceThreshold: group
                                                    .minimumBalanceThreshold,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.account_balance_wallet_outlined,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Add Balance',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Delete Icon
                            IconButton(
                              icon: Icon(
                                Icons.delete_forever,
                                color: isGroupAdmin
                                    ? AppColors.errorRed
                                    : AppColors.hintGrey.withOpacity(0.5),
                                size: 28,
                              ),
                              onPressed: () => _deleteGroup(
                                group.groupId,
                                group.groupName,
                                group.creatorUid,
                              ),
                              tooltip: isGroupAdmin
                                  ? 'Delete group'
                                  : 'Only group admin can delete',
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTabContent() {
    return StreamBuilder<List<GroupModel>>(
      stream: _groupService.getUsersGroups(),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accentGreen),
          );
        }
        if (groupSnapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${groupSnapshot.error}',
              style: const TextStyle(color: AppColors.errorRed),
            ),
          );
        }

        final groups = groupSnapshot.data ?? [];
        if (groups.isEmpty) {
          return const Center(
            child: Text(
              'No groups found. Join or create a group to see history.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.hintGrey, fontSize: 16),
            ),
          );
        }

        final Map<String, GroupModel> groupIdToGroup = {
          for (final g in groups) g.groupId: g,
        };
        final List<String> groupIds = groupIdToGroup.keys.toList();

        return StreamBuilder<List<ExpenseModel>>(
          stream: _groupService.getExpensesForGroupIds(groupIds),
          builder: (context, expSnapshot) {
            if (expSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accentGreen),
              );
            }
            if (expSnapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading expenses: ${expSnapshot.error}',
                  style: const TextStyle(color: AppColors.errorRed),
                ),
              );
            }

            final expenses = expSnapshot.data ?? [];
            if (expenses.isEmpty) {
              return const Center(
                child: Text(
                  'No expenses yet.',
                  style: TextStyle(color: AppColors.hintGrey),
                ),
              );
            }

            final grouped = _groupExpensesByDate(expenses);
            final sortedDates = grouped.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: sortedDates.length,
              itemBuilder: (context, dateIndex) {
                final dateKey = sortedDates[dateIndex];
                final dayExpenses = grouped[dateKey]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: AppColors.primaryBackground,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        _formatDateLabel(dateKey),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.hintGrey,
                        ),
                      ),
                    ),
                    for (final e in dayExpenses)
                      Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(e.description),
                          subtitle: Text(
                            '${groupIdToGroup[e.groupId]?.groupName ?? 'Unknown Group'} • ${e.category} • Paid by ${e.paidBy}',
                          ),
                          trailing: Text(
                            '₹${e.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onTap: () {
                            _showExpenseDetails(
                              e,
                              groupIdToGroup[e.groupId]?.groupName ?? 'Group',
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showExpenseDetails(ExpenseModel e, String groupName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: AppColors.textLight,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.description,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    '₹${e.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Group: $groupName',
                style: const TextStyle(color: AppColors.hintGrey),
              ),
              const SizedBox(height: 4),
              Text(
                'Category: ${e.category}',
                style: const TextStyle(color: AppColors.hintGrey),
              ),
              const SizedBox(height: 4),
              Text(
                'Paid by: ${e.paidBy}',
                style: const TextStyle(color: AppColors.hintGrey),
              ),
              const SizedBox(height: 4),
              Text(
                'Date: ${_formatDateLabel(_yyyyMmDd(e.date))}',
                style: const TextStyle(color: AppColors.hintGrey),
              ),
              const SizedBox(height: 12),
              if (e.billImageUrl != null && e.billImageUrl!.isNotEmpty)
                Text(
                  'Bill: ${e.billImageUrl}',
                  style: const TextStyle(color: AppColors.hintGrey),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Map<String, List<ExpenseModel>> _groupExpensesByDate(
    List<ExpenseModel> expenses,
  ) {
    final Map<String, List<ExpenseModel>> grouped = {};
    for (final e in expenses) {
      final key = _yyyyMmDd(e.date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(e);
    }
    return grouped;
  }

  String _yyyyMmDd(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _formatDateLabel(String ymd) {
    // ymd is in form YYYY-MM-DD
    final parts = ymd.split('-');
    if (parts.length != 3) return ymd;
    final year = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 1;
    final day = int.tryParse(parts[2]) ?? 1;
    final dt = DateTime(year, month, day);
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isYesterday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day - 1;
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${day.toString().padLeft(2, '0')} ${monthNames[month - 1]} $year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: Text(_getAppBarTitle(_selectedIndex)),
        backgroundColor: AppColors.accentGreen,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          if (_selectedIndex == 2)
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.textDark, size: 28),
              onPressed: _navigateToUpdateProfile,
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.accentGreen),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppColors.textLight,
                backgroundImage:
                    (_firebaseAuth.currentUser?.photoURL != null &&
                        _firebaseAuth.currentUser!.photoURL!.isNotEmpty)
                    ? NetworkImage(_firebaseAuth.currentUser!.photoURL!)
                    : null,
                child:
                    (_firebaseAuth.currentUser?.photoURL == null ||
                        _firebaseAuth.currentUser!.photoURL!.isEmpty)
                    ? Text(
                        (_firebaseAuth.currentUser?.displayName?.isNotEmpty ==
                                true)
                            ? _firebaseAuth.currentUser!.displayName![0]
                                  .toUpperCase()
                            : (_firebaseAuth.currentUser?.email?.isNotEmpty ==
                                  true)
                            ? _firebaseAuth.currentUser!.email![0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              accountName: Text(
                _firebaseAuth.currentUser?.displayName ?? 'User',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              accountEmail: Text(
                _firebaseAuth.currentUser?.email ?? '',
                style: const TextStyle(color: AppColors.textDark),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                _onItemTapped(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Create Group'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateGroupScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              onTap: () {
                _onItemTapped(1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                _onItemTapped(2);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.errorRed),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
    );
  }
}
