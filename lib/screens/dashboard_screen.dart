import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/auth_provider.dart';
import '../provider/clearance_state_provider.dart';
import '../screens/apply_clearance_screen.dart';
import '../screens/clearance_feedback_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final clearanceProvider = Provider.of<ClearanceStateProvider>(context);
    final userName = authProvider.user?.username;
    final hasSubmittedApplication = clearanceProvider.hasSubmittedApplication;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 4,
      ),
      drawer: Drawer(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withAlpha(204),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/image/nit_logo.png',
                      height: 100,
                      width: 100,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userName!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Student',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                AnimatedExpansionTile(
                  leading: const Icon(Icons.clear_all, color: Colors.indigo),
                  title: const Text(
                    'Clearance',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo,
                    ),
                  ),
                  children: [
                    _buildDrawerItem(
                      context,
                      icon: hasSubmittedApplication
                          ? Icons.feedback
                          : Icons.edit_document,
                      title: hasSubmittedApplication
                          ? 'Clearance Feedback'
                          : 'Apply Clearance',
                      onTap: () {
                        print(
                            'Navigating to ${hasSubmittedApplication ? 'Clearance Feedback' : 'Apply Clearance'}');
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => hasSubmittedApplication
                                ? const ClearanceFeedbackScreen()
                                : const ApplyClearanceScreen(),
                          ),
                        );
                      },
                    ),
                    if (!hasSubmittedApplication)
                      _buildDrawerItem(
                        context,
                        icon: Icons.feedback,
                        title: 'Clearance Feedback',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ClearanceFeedbackScreen(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.logout,
                  title: 'Logout',
                  iconColor: Colors.red,
                  textColor: Colors.red,
                  onTap: () async {
                    Navigator.pop(context);
                    await authProvider.logout();
                    await clearanceProvider.clearData();
                    Navigator.pushReplacementNamed(context, '/');
                  },
                ),
              ]),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/image/nit_logo.png',
                        height: 200,
                        width: 200,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome to NIT Clearance System',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The National Institute of Transport (NIT) Clearance System allows students to apply for clearance and track their feedback. Use the drawer menu to navigate to "Apply Clearance" to submit your request or "Clearance Feedback" to view your clearance status.',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = Colors.indigo,
    Color textColor = Colors.black87,
  }) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedExpansionTile extends StatefulWidget {
  final Widget leading;
  final Widget title;
  final List<Widget> children;

  const AnimatedExpansionTile({
    super.key,
    required this.leading,
    required this.title,
    required this.children,
  });

  @override
  _AnimatedExpansionTileState createState() => _AnimatedExpansionTileState();
}

class _AnimatedExpansionTileState extends State<AnimatedExpansionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: widget.leading,
      title: widget.title,
      onExpansionChanged: (expanded) {
        if (expanded) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      },
      trailing: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value * 3.14,
            child: const Icon(Icons.expand_more, color: Colors.indigo),
          );
        },
      ),
      children: widget.children,
    );
  }
}
