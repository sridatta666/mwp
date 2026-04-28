import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/supabase_service.dart';
import '../../core/models.dart';
import '../../core/bunny_service.dart';
import '../../core/theme.dart';
import '../../core/favorites_service.dart';
import '../../core/glass_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Program? _featuredProgram;
  List<Workout> _allWorkouts = [];
  List<Program> _allPrograms = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _difficultyFilter;
  final _favoritesService = FavoritesService();
  Set<String> _favoriteWorkoutIds = {};
  Set<String> _favoriteProgramIds = {};

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
    _loadFavorites();
  }

  void _loadFavorites() {
    setState(() {
      _favoriteWorkoutIds = _favoritesService.getFavoriteWorkoutIds();
      _favoriteProgramIds = _favoritesService.getFavoriteProgramIds();
    });
  }

  Future<void> _fetchHomeData() async {
    final service = SupabaseService();
    final results = await Future.wait([
      service.fetchFeaturedProgram(),
      service.fetchAllWorkouts(),
      service.fetchAllPrograms(),
    ]);
    if (mounted) {
      setState(() {
        _featuredProgram = results[0] as Program?;
        _allWorkouts = results[1] as List<Workout>;
        _allPrograms = results[2] as List<Program>;
        _isLoading = false;
      });
    }
  }

  List<Workout> _filterWorkouts(List<Workout> list) {
    var out = list;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      out = out.where((w) => w.title.toLowerCase().contains(q)).toList();
    }
    if (_difficultyFilter != null && _difficultyFilter!.isNotEmpty) {
      out = out.where((w) => w.difficulty == _difficultyFilter).toList();
    }
    return out;
  }

  List<Program> _filterPrograms(List<Program> list) {
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((p) => p.title.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final traditional = _filterWorkouts(_allWorkouts.where((w) => w.type == 'standard').toList());
    final followAlong = _filterWorkouts(_allWorkouts.where((w) => w.type == 'sequence').toList());
    final programs = _filterPrograms(_allPrograms);
    final favoriteWorkouts = _allWorkouts.where((w) => _favoriteWorkoutIds.contains(w.id)).toList();
    final favoritePrograms = _allPrograms.where((p) => _favoriteProgramIds.contains(p.id)).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GlassPage(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _fetchHomeData();
              _loadFavorites();
            },
            color: Theme.of(context).colorScheme.primary,
            child: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                elevation: 0,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                titleSpacing: 16,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mind and Weight Project',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      'Discover',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: IconButton(
                      icon: const Icon(Icons.person_rounded),
                      onPressed: () => context.push('/profile'),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),

              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Search workouts, programs, difficulty',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
                        prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.outline),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                color: Theme.of(context).colorScheme.outline,
                                onPressed: () => setState(() => _searchQuery = ''),
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                  ),
                ),
              ),

              // Difficulty filter chips
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildChip(theme, null, 'All'),
                      const SizedBox(width: 8),
                      _buildChip(theme, 'Beginner', 'Beginner'),
                      const SizedBox(width: 8),
                      _buildChip(theme, 'Intermediate', 'Intermediate'),
                      const SizedBox(width: 8),
                      _buildChip(theme, 'Advanced', 'Advanced'),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Favorites section
              if (favoriteWorkouts.isNotEmpty || favoritePrograms.isNotEmpty) ...[
                _sectionHeader('Favorites', 'Quick access', theme),
                if (favoriteWorkouts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 148,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: favoriteWorkouts.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _WorkoutCard(
                            workout: favoriteWorkouts[i],
                            isFavorite: true,
                            onFavoriteToggle: () => _toggleWorkoutFavorite(favoriteWorkouts[i].id),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (favoritePrograms.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        height: 132,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: favoritePrograms.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _ProgramCard(
                              program: favoritePrograms[i],
                              isFavorite: true,
                              onFavoriteToggle: () => _toggleProgramFavorite(favoritePrograms[i].id),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // Featured program
              if (_featuredProgram != null && (_searchQuery.isEmpty || _featuredProgram!.title.toLowerCase().contains(_searchQuery.toLowerCase())))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: _FeaturedBanner(program: _featuredProgram!),
                  ),
                ),

              // Traditional
              if (traditional.isNotEmpty) ...[
                _sectionHeader('Traditional', 'Sets & reps', theme),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 148,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: traditional.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _WorkoutCard(
                          workout: traditional[i],
                          isFavorite: _favoriteWorkoutIds.contains(traditional[i].id),
                          onFavoriteToggle: () => _toggleWorkoutFavorite(traditional[i].id),
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // Follow along
              if (followAlong.isNotEmpty) ...[
                _sectionHeader('Follow along', 'Video workouts', theme),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 148,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: followAlong.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _WorkoutCard(
                          workout: followAlong[i],
                          isFavorite: _favoriteWorkoutIds.contains(followAlong[i].id),
                          onFavoriteToggle: () => _toggleWorkoutFavorite(followAlong[i].id),
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],

              // Programs
              _sectionHeader('Programs', 'Multi-week plans', theme),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 132,
                  child: programs.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Center(
                            child: Text(
                              _searchQuery.isEmpty ? 'No programs' : 'No matching programs',
                              style: theme.textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline),
                            ),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: programs.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _ProgramCard(
                              program: programs[i],
                              isFavorite: _favoriteProgramIds.contains(programs[i].id),
                              onFavoriteToggle: () => _toggleProgramFavorite(programs[i].id),
                            ),
                          ),
                        ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleWorkoutFavorite(String id) async {
    await _favoritesService.toggleWorkoutFavorite(id);
    _loadFavorites();
  }

  Future<void> _toggleProgramFavorite(String id) async {
    await _favoritesService.toggleProgramFavorite(id);
    _loadFavorites();
  }

  Widget _buildChip(ThemeData theme, String? value, String label) {
    final selected = _difficultyFilter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _difficultyFilter = selected ? null : value),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
      checkmarkColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle, ThemeData theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final Workout workout;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const _WorkoutCard({required this.workout, required this.isFavorite, required this.onFavoriteToggle});

  String _thumbnailVideoId() {
    if (workout.type == 'sequence' && workout.clips.isNotEmpty) {
      return workout.clips.first.videoId;
    }
    return workout.videoId;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/workout/${workout.id}'),
      child: SizedBox(
        width: 140,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: BunnyService.getThumbnailUrl(_thumbnailVideoId()),
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(color: Theme.of(context).colorScheme.surface),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.88)],
                      stops: const [0.35, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onFavoriteToggle,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.38),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFavorite ? Theme.of(context).colorScheme.secondary : Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (workout.type == 'sequence')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'SEQUENCE',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.background,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      if (workout.type == 'sequence') const SizedBox(height: 6),
                      Text(
                        workout.title,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            '${workout.duration} min',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedBanner extends StatelessWidget {
  final Program program;

  const _FeaturedBanner({required this.program});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/program/${program.id}'),
      child: Container(
        height: 128,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: AppTheme.heroGradient,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'FEATURED',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    program.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${program.totalWeeks} week plan',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final Program program;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const _ProgramCard({required this.program, required this.isFavorite, required this.onFavoriteToggle});

  bool get _hasProgramImage {
    return program.imageUrl != null && program.imageUrl!.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/program/${program.id}'),
      child: SizedBox(
        width: 160,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_hasProgramImage)
                      CachedNetworkImage(
                        imageUrl: program.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(color: Theme.of(context).colorScheme.surface),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.surface,
                              Theme.of(context).colorScheme.primary.withOpacity(0.18),
                            ],
                          ),
                        ),
                        child: Icon(Icons.fitness_center_rounded, size: 32, color: Theme.of(context).colorScheme.primary.withOpacity(0.55)),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: onFavoriteToggle,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFavorite ? Theme.of(context).colorScheme.secondary : Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      program.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${program.totalWeeks} weeks',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
