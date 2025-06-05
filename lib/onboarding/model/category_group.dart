import 'package:flutter/material.dart';

class CategoryGroup {
  final String title;
  final IconData icon;
  final List<String> categories;
  final Color color;

  const CategoryGroup({required this.title, required this.icon, required this.categories, required this.color});

  static List<CategoryGroup> get defaultGroups => [
    CategoryGroup(
      title: 'Productivity',
      icon: Icons.work_outline,
      color: const Color(0xFF2196F3), // CP: Blue for work
      categories: ['Projects 📋', 'Goals 🎯', 'Ideas 💡', 'Problems ⚠️', 'Solutions ✅', 'Work 💼', 'Meetings 🤝'],
    ),
    CategoryGroup(
      title: 'Personal Life',
      icon: Icons.home_outlined,
      color: const Color(0xFF4CAF50), // CP: Green for personal
      categories: [
        'Personal 👤',
        'Family 👨‍👩‍👧‍👦',
        'Relationships 💕',
        'Home 🏠',
        'Daily 📅',
        'Memories 📸',
        'Events 🎉',
        'Rants 😤',
        'Hot Takes 🔥',
      ],
    ),
    CategoryGroup(
      title: 'Health & Wellness',
      icon: Icons.favorite_outline,
      color: const Color(0xFFE91E63), // CP: Pink for health
      categories: ['Health 🏥', 'Exercise 💪', 'Mood 😊', 'Habits 🔄', 'Skincare ✨', 'Self Care 🧘‍♀️'],
    ),
    CategoryGroup(
      title: 'Learning & Growth',
      icon: Icons.school_outlined,
      color: const Color(0xFF9C27B0), // CP: Purple for learning
      categories: ['Learning 📚', 'Books 📖', 'Quotes 💭', 'Inspiration 🌟', 'Reflections 🤔'],
    ),
    CategoryGroup(
      title: 'Lifestyle & Interests',
      icon: Icons.palette_outlined,
      color: const Color(0xFFFF9800), // CP: Orange for lifestyle
      categories: ['Food 🍕', 'Travel ✈️', 'Hobbies 🎨', 'Movies 🎬', 'Music 🎵', 'Shopping 🛍️'],
    ),
    CategoryGroup(
      title: 'Planning & Tracking',
      icon: Icons.event_note_outlined,
      color: const Color(0xFF607D8B), // CP: Blue Grey for planning
      categories: [
        'Finance 💰',
        'Reminders 📝',
        'Weekly 📊',
        'Monthly 📈',
        'Gratitude 🙏',
        'Dreams 💭',
        'Bucket List ✨',
      ],
    ),
  ];
}
