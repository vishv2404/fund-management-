import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fund_management_app/models/group_model.dart';
import 'package:fund_management_app/models/expense_model.dart';
import 'package:fund_management_app/utils/app_constants.dart';
import 'package:fund_management_app/utils/custom_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fund_management_app/screens/add_members_to_group_screen.dart';
import 'package:fund_management_app/screens/add_expense_screen.dart';
import 'package:fund_management_app/services/auth_service.dart';
import 'package:fund_management_app/services/group_service.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
// Removed fl_chart import to restore custom painter version

class GroupDetailsScreen extends StatefulWidget {
  final GroupModel group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen>
    with SingleTickerProviderStateMixin {
  bool _showFabOptions = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final GroupService _groupService = GroupService();
  String? _creatorUsername;
  late TabController _tabController;
  int? _selectedSliceIndex;

  Map<String, String> _memberUsernames = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCreatorUsername();
    _fetchMemberUsernames();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchCreatorUsername() async {
    final userModel = await _authService.getUserData(widget.group.creatorUid);
    if (mounted) {
      setState(() {
        _creatorUsername = userModel?.username ?? 'Unknown User';
      });
    }
  }

  Future<void> _fetchMemberUsernames() async {
    Map<String, String> fetchedUsernames = {};
    for (String memberEmail in widget.group.members) {
      String? username = await _authService.getUsernameByEmail(memberEmail);
      fetchedUsernames[memberEmail] = username ?? memberEmail.split('@')[0];
    }
    if (mounted) {
      setState(() {
        _memberUsernames = fetchedUsernames;
      });
    }
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

  void _toggleFabOptions() {
    setState(() {
      _showFabOptions = !_showFabOptions;
    });
  }

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

  Map<String, dynamic> _getExpenseCategoryIconAndColor(String categoryName) {
    return AppConstants.expenseCategories.firstWhere(
      (cat) => cat['name'] == categoryName,
      orElse: () => {
        'name': 'Other',
        'icon': Icons.category,
        'color': AppColors.hintGrey,
      },
    );
  }

  // Helper method to display loading/error state for GroupDetailsScreen's main stream
  Widget _buildLoadingOrErrorGroupDetails(
    GroupModel group,
    String? currentUserUid,
    bool isAdmin,
    Map<String, dynamic> categoryData, {
    dynamic error,
  }) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 15.0,
              ),
              color: AppColors.primaryBackground,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: AppColors.textDark,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    categoryData['icon'],
                    color: categoryData['color'],
                    size: 38,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.groupName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Created by ${_creatorUsername ?? 'Loading...'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.hintGrey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_forever,
                      color: isAdmin
                          ? AppColors.errorRed
                          : AppColors.hintGrey.withOpacity(0.5),
                    ),
                    onPressed: () {
                      _showToast(
                        "Delete functionality (from error state)",
                        AppColors.hintGrey,
                      );
                    },
                    tooltip: isAdmin
                        ? 'Delete group'
                        : 'Only group admin can delete',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      error != null
                          ? Icons.error_outline
                          : Icons.cloud_download,
                      size: 80,
                      color: error != null
                          ? AppColors.errorRed
                          : AppColors.hintGrey,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      error != null
                          ? 'Error loading group: $error'
                          : 'Loading group data...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: error != null
                            ? AppColors.errorRed
                            : AppColors.hintGrey,
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Please check your internet connection or Firebase rules.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.hintGrey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showToast("Loading, please wait...", AppColors.hintGrey);
        },
        backgroundColor: AppColors.hintGrey,
        foregroundColor: AppColors.textLight,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserUid = _auth.currentUser?.uid;
    final String? currentUserEmail = _auth.currentUser?.email;
    final bool isAdmin = currentUserUid == widget.group.creatorUid;
    final categoryData = _getCategoryIconAndColor(widget.group.groupCategory);

    // Stream group data for real-time updates of memberBalances
    return StreamBuilder<GroupModel>(
      stream: _groupService.getGroupById(widget.group.groupId),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingOrErrorGroupDetails(
            widget.group,
            currentUserUid,
            isAdmin,
            categoryData,
          );
        }
        if (groupSnapshot.hasError || !groupSnapshot.hasData) {
          return _buildLoadingOrErrorGroupDetails(
            widget.group,
            currentUserUid,
            isAdmin,
            categoryData,
            error: groupSnapshot.error,
          );
        }

        final GroupModel currentGroupState = groupSnapshot.data!;

        // Calculate Group Total Balance
        double groupTotalBalance = currentGroupState.memberBalances.values.fold(
          0.0,
          (sum, balance) => sum + balance,
        );

        // Get current user's balance for this group
        double currentUserPersonalBalance =
            currentGroupState.memberBalances[currentUserEmail] ?? 0.0;

        return Scaffold(
          backgroundColor: AppColors.primaryBackground,
          body: SafeArea(
            child: Column(
              children: [
                // Custom Top Bar Section
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 15.0,
                  ),
                  color: AppColors.primaryBackground,
                  child: Row(
                    children: [
                      // Back button
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: AppColors.textDark,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 10),
                      // Category Icon
                      Icon(
                        categoryData['icon'],
                        color: categoryData['color'],
                        size: 38,
                      ),
                      const SizedBox(width: 15),
                      // Group Name and Creator
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentGroupState
                                  .groupName, // Use updated group state
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Created by ${_creatorUsername ?? 'Loading...'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.hintGrey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Delete Icon (remain on the right)
                      IconButton(
                        icon: Icon(
                          Icons.delete_forever,
                          color: isAdmin
                              ? AppColors.errorRed
                              : AppColors.hintGrey.withOpacity(0.5),
                          size: 28,
                        ),
                        onPressed: () {
                          if (isAdmin) {
                            _showToast(
                              "Delete group functionality not implemented yet.",
                              AppColors.hintGrey,
                            );
                          } else {
                            _showToast(
                              'You are not the admin of this group and cannot delete it.',
                              AppColors.errorRed,
                            );
                          }
                        },
                        tooltip: isAdmin
                            ? 'Delete group'
                            : 'Only group admin can delete',
                      ),
                    ],
                  ),
                ),
                // Group Total Balance and Personal Balance Display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  color: AppColors.cardBackground,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        // Group Total
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Group Total:',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.hintGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '₹${groupTotalBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: groupTotalBalance >= 0
                                  ? AppColors.successGreen
                                  : AppColors.errorRed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        // Your Personal Balance
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Personal Balance:',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.hintGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '₹${currentUserPersonalBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: currentUserPersonalBalance >= 0
                                  ? AppColors.successGreen
                                  : AppColors.errorRed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 10.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textLight,
                    borderRadius: BorderRadius.circular(15.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.buttonShadow.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(15.0),
                      color: AppColors.accentGreen,
                    ),
                    labelColor: AppColors.textDark,
                    unselectedLabelColor: AppColors.hintGrey,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 16,
                    ),
                    tabs: const [
                      Tab(text: 'Expense'),
                      Tab(text: 'Summary'),
                    ],
                  ),
                ),
                // Tab Bar View
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Expense Tab Content
                      _buildExpenseTabContent(currentUserEmail),
                      // Summary Tab Content
                      _buildSummaryTabContent(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Add Expense Button
              AnimatedOpacity(
                opacity: _showFabOptions ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_showFabOptions,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: FloatingActionButton.extended(
                      onPressed: () {
                        if (_showFabOptions) {
                          _toggleFabOptions();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddExpenseScreen(
                                group: currentGroupState,
                              ), // Pass updated group state
                            ),
                          );
                        }
                      },
                      label: const Text(
                        'Add Expense',
                        style: TextStyle(color: AppColors.textDark),
                      ),
                      icon: const Icon(
                        Icons.add_shopping_cart,
                        color: AppColors.textDark,
                      ),
                      backgroundColor: AppColors.accentGreen,
                      heroTag: 'addExpenseFab',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  ),
                ),
              ),
              // Add Members Button (only visible/tappable if current user is admin)
              if (isAdmin)
                AnimatedOpacity(
                  opacity: _showFabOptions ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_showFabOptions,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: FloatingActionButton.extended(
                        onPressed: () {
                          if (_showFabOptions) {
                            _toggleFabOptions();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddMembersToGroupScreen(
                                  group: currentGroupState,
                                ), // Pass updated group state
                              ),
                            );
                          }
                        },
                        label: const Text(
                          'Add Members',
                          style: TextStyle(color: AppColors.textDark),
                        ),
                        icon: const Icon(
                          Icons.person_add,
                          color: AppColors.textDark,
                        ),
                        backgroundColor: AppColors.accentGreen,
                        heroTag: 'addMembersFab',
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  ),
                ),
              // Main Plus FAB
              FloatingActionButton(
                onPressed: _toggleFabOptions,
                backgroundColor: AppColors.accentGreen,
                foregroundColor: AppColors.textDark,
                heroTag: 'mainFab',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: Icon(
                  _showFabOptions ? Icons.close : Icons.add,
                  size: 30,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpenseTabContent(String? currentUserEmail) {
    return StreamBuilder<List<ExpenseModel>>(
      stream: _groupService.getExpensesForGroup(widget.group.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accentGreen),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading expenses: ${snapshot.error}',
              style: const TextStyle(color: AppColors.errorRed),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 80,
                  color: AppColors.hintGrey.withOpacity(0.5),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No expenses yet. Click the + button to add one!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.hintGrey),
                ),
              ],
            ),
          );
        }

        List<ExpenseModel> expenses = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final expense = expenses[index];
            final expenseCategoryData = _getExpenseCategoryIconAndColor(
              expense.category,
            );

            String paidByName =
                _memberUsernames[expense.paidBy] ??
                expense.paidBy.split('@')[0];

            String currentUserOwedStatus = '';
            Color currentUserOwedColor = AppColors.textDark;

            if (currentUserEmail == null) {
              currentUserOwedStatus = '';
              currentUserOwedColor = AppColors.textDark;
            } else if (expense.shares.containsKey(currentUserEmail)) {
              double share = expense.shares[currentUserEmail]!;
              if (share > 0) {
                // If the current user has a share (owes)
                if (expense.paidBy == currentUserEmail) {
                  // If current user is also the payer, their net effect from this transaction.
                  // Balance decreased by full amount paid, then increased by their share.
                  // Net change: share - amount. If amount is greater than share, they are effectively owed.
                  // If share is greater than amount (e.g. they paid less than their share, or didn't pay but took part in split), they owe.
                  double netEffectForPayer = share - expense.amount;
                  if (netEffectForPayer < 0) {
                    currentUserOwedStatus =
                        'You are owed ₹${netEffectForPayer.abs().toStringAsFixed(2)}';
                    currentUserOwedColor = AppColors.successGreen;
                  } else if (netEffectForPayer > 0) {
                    currentUserOwedStatus =
                        'You paid but owe ₹${netEffectForPayer.abs().toStringAsFixed(2)}';
                    currentUserOwedColor = AppColors.errorRed;
                  } else {
                    currentUserOwedStatus =
                        'You paid exactly your share (settled)';
                    currentUserOwedColor = AppColors.hintGrey;
                  }
                } else {
                  // Current user is not payer and owes a share
                  currentUserOwedStatus =
                      'You owe ₹${share.toStringAsFixed(2)}';
                  currentUserOwedColor = AppColors.errorRed;
                }
              } else {
                currentUserOwedStatus = 'You are covered (owes ₹0.00)';
                currentUserOwedColor = AppColors.hintGrey;
              }
            } else {
              currentUserOwedStatus = 'Not involved';
              currentUserOwedColor = AppColors.hintGrey;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 3,
              color: AppColors.cardBackground,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          expenseCategoryData['icon'],
                          color: expenseCategoryData['color'],
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.description,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                'Category: ${expense.category}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.hintGrey.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${expense.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              DateFormat('dd MMM yy').format(expense.date),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.hintGrey.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Paid by: $paidByName',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark.withOpacity(0.8),
                      ),
                    ),
                    // Display split details for each member
                    const SizedBox(height: 10),
                    const Text(
                      'Split Details:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: expense.shares.length,
                      itemBuilder: (context, idx) {
                        String memberEmail = expense.shares.keys.elementAt(idx);
                        double shareAmount = expense.shares.values.elementAt(
                          idx,
                        );
                        String memberDisplayName =
                            _memberUsernames[memberEmail] ??
                            memberEmail.split('@')[0];

                        String splitText;
                        Color splitColor;

                        if (memberEmail == expense.paidBy) {
                          // Payer's perspective in pooled fund:
                          splitText =
                              '$memberDisplayName paid ₹${expense.amount.toStringAsFixed(2)} (covered own share: ₹${shareAmount.toStringAsFixed(2)})';
                          splitColor = AppColors.successGreen;
                        } else {
                          // Non-payer's perspective: their balance decreases by their share.
                          if (shareAmount > 0) {
                            splitText =
                                '$memberDisplayName\'s pool share decreased by ₹${shareAmount.toStringAsFixed(2)}';
                            splitColor = AppColors.errorRed;
                          } else {
                            splitText =
                                '$memberDisplayName\'s pool share is unchanged (owes ₹0.00)';
                            splitColor = AppColors.hintGrey;
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            children: [
                              Expanded(
                                // Ensure text wraps
                                child: Text(
                                  '• $splitText',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: splitColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Divider(height: 20, color: AppColors.borderColor),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Status:',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textDark.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          currentUserOwedStatus,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: currentUserOwedColor,
                          ),
                        ),
                      ],
                    ),
                    if (expense.billImageUrl != null &&
                        expense.billImageUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () {
                              _showToast(
                                "Viewing bill image (not implemented)",
                                AppColors.hintGrey,
                              );
                            },
                            child: Text(
                              'View Bill Image',
                              style: TextStyle(
                                color: AppColors.accentGreen,
                                decoration: TextDecoration.underline,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryTabContent() {
    return StreamBuilder<List<ExpenseModel>>(
      stream: _groupService.getExpensesForGroup(widget.group.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accentGreen),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading summary: ${snapshot.error}',
              style: const TextStyle(color: AppColors.errorRed),
            ),
          );
        }
        final expenses = snapshot.data ?? [];
        if (expenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pie_chart_outline,
                  size: 80,
                  color: AppColors.hintGrey.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No expenses yet to summarize.',
                  style: TextStyle(color: AppColors.hintGrey),
                ),
              ],
            ),
          );
        }

        final Map<String, double> totalsByCategory = {};
        for (final e in expenses) {
          totalsByCategory.update(
            e.category,
            (v) => v + e.amount,
            ifAbsent: () => e.amount,
          );
        }
        final totalAmount = totalsByCategory.values.fold<double>(
          0.0,
          (a, b) => a + b,
        );

        final slices = totalsByCategory.entries.map((entry) {
          final category = entry.key;
          final amount = entry.value;
          final color = _getColorForCategory(category);
          return _PieSlice(category: category, value: amount, color: color);
        }).toList()..sort((a, b) => b.value.compareTo(a.value));

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Add extra top spacing to move chart down
              const SizedBox(height: 20),
              // Legend chips row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    for (int i = 0; i < slices.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(
                            slices[i].category,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: _selectedSliceIndex == i,
                          onSelected: (_) {
                            setState(() => _selectedSliceIndex = i);
                          },
                          backgroundColor: slices[i].color.withOpacity(0.18),
                          selectedColor: slices[i].color.withOpacity(0.32),
                          avatar: CircleAvatar(
                            backgroundColor: slices[i].color,
                            radius: 5,
                          ),
                          shape: StadiumBorder(
                            side: BorderSide(color: slices[i].color),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Move chart a bit lower with extra top space
              const SizedBox(height: 40),
              LayoutBuilder(
                builder: (context, constraints) {
                  final chartHeight = constraints.maxHeight.isFinite
                      ? (constraints.maxHeight * 0.38).clamp(200.0, 340.0)
                      : 250.0;
                  return SizedBox(
                    height: chartHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final size = box.size;
                        final center = Offset(size.width / 2, chartHeight / 2);
                        final local = details.localPosition;
                        final dx = local.dx - center.dx;
                        final dy = local.dy - center.dy;
                        final dist = math.sqrt(dx * dx + dy * dy);
                        // Recreate radii logic from painter to determine if tap is within ring
                        final baseRadius = math.min(size.width, chartHeight) * 0.42;
                        final holeRadius = baseRadius * 0.55;
                        final outerR = baseRadius / 2 + holeRadius + 16; // include tolerance
                        final innerR = holeRadius;
                        if (dist < innerR || dist > outerR) {
                          setState(() => _selectedSliceIndex = null);
                          return;
                        }
                        double angle = math.atan2(dy, dx); // -pi..pi from +x axis
                        double fromTop = angle - (-math.pi / 2);
                        if (fromTop < 0) fromTop += 2 * math.pi;
                        final total = slices.fold<double>(0.0, (a, b) => a + b.value);
                        double acc = 0.0;
                        int? hitIndex;
                        for (int i = 0; i < slices.length; i++) {
                          final sweep = (slices[i].value / total) * 2 * math.pi;
                          if (fromTop >= acc && fromTop < acc + sweep) {
                            hitIndex = i;
                            break;
                          }
                          acc += sweep;
                        }
                        setState(() => _selectedSliceIndex = hitIndex);
                      },
                      child: CustomPaint(
                        painter: _PieChartPainter(
                          slices: slices,
                          selectedIndex: _selectedSliceIndex,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(color: AppColors.hintGrey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              if (_selectedSliceIndex != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${slices[_selectedSliceIndex!].category}: ₹${slices[_selectedSliceIndex!].value.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    );
                  },
              ),
              const SizedBox(height: 16),
              // Removed bottom expense list
            ],
          ),
        );
      },
    );
  }
}

class _PieSlice {
  final String category;
  final double value;
  final Color color;
  _PieSlice({required this.category, required this.value, required this.color});
}

// Returns a vibrant color for a given category. Uses existing category color mapping when available,
// otherwise assigns a deterministic color from a vivid palette.
Color _getColorForCategory(String category) {
  const palette = <Color>[
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.amber,
    Colors.pink,
    Colors.indigo,
    Colors.cyan,
    Colors.lime,
    Colors.deepOrange,
    Colors.deepPurple,
  ];
  int hash = category.codeUnits.fold(0, (a, b) => (a * 31 + b) & 0x7fffffff);
  return palette[hash % palette.length];
}

class _PieChartPainter extends CustomPainter {
  final List<_PieSlice> slices;
  final int? selectedIndex;
  _PieChartPainter({required this.slices, this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = rect.center;
    final baseRadius = size.shortestSide * 0.42;

    final total = slices.fold<double>(0.0, (a, b) => a + b.value);
    if (total <= 0) return;

    double startRadian = -math.pi / 2; // start at top
    final holeRadius = baseRadius * 0.55;

    for (int i = 0; i < slices.length; i++) {
      final s = slices[i];
      final sweepRadian = (s.value / total) * 2 * math.pi;
      final isSelected = selectedIndex == i;
      final strokeWidth = baseRadius + (isSelected ? 10.0 : 0.0);
      final outerRadius =
          baseRadius / 2 + holeRadius + (isSelected ? 6.0 : 0.0);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = strokeWidth
        ..color = s.color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        startRadian,
        sweepRadian,
        false,
        paint,
      );

      // Optional highlight outline
      if (isSelected) {
        final border = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = s.color.withOpacity(0.9);
        canvas.drawArc(
          Rect.fromCircle(
            center: center,
            radius: outerRadius + strokeWidth / 2 + 1,
          ),
          startRadian,
          sweepRadian,
          false,
          border,
        );
      }

      startRadian += sweepRadian;
    }

    // Draw inner hole to make it donut-style
    final holePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, holeRadius, holePaint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.slices != slices;
}
