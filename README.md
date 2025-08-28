# Office_Booking_v1
Phoenix LiveView Office Booking System 

## Project Overview
Web application using Elixir Phoenix LiveView for internal office room booking within a company. Employees can view, book, and negotiate room usage with real-time updates and messaging capabilities.

## Core Requirements

### **User System**
- Employee authentication (Phoenix.gen.auth)
- Two user types: Regular employees (equal access) + Admins (management capabilities)
- User profiles: first_name, last_name, email, phone, department

### **Room Management**
- Rooms with: name, description, capacity, location, features (LCD, whiteboard, etc.)
- Multiple photos per room with primary photo selection
- Public gallery view (no auth required) showing all rooms with photos and features
- Admin can manage room details, features, and photos

### **Booking System**
- **Flexible duration booking** (no fixed hourly/daily limits)
- **Business hours only**: 10 AM - 10 PM CET timezone
- **Advance booking limit**: Maximum 2 days in advance
- **Conflict handling**: System prevents overlaps but shows current renter info for negotiation
- **No payment needed** (free internal system)
- **Real-time availability updates** across all users

### **Communication Features**
- Message system between users for room negotiation
- Contact current room renter directly from room view
- Conversation threading and unread message tracking
- Real-time messaging notifications via PubSub

### **Two Main Views**
1. **Public View**: Browse rooms, see current/upcoming bookings, contact renters
2. **User Dashboard**: My bookings, create new bookings, message inbox

### **Admin Capabilities**
- Manage all room details and features
- Cancel/modify any booking for conflict resolution
- User management (view all users, toggle admin status)
- Full system oversight

## Technical Stack
- **Backend**: Elixir Phoenix LiveView
- **Database**: PostgreSQL with Ecto
- **UI**: Tailwind CSS
- **File uploads**: Local storage for room photos
- **Real-time**: Phoenix PubSub for live updates and notifications


## Key Features Implementation

### **Smart Booking Logic**
- Check availability before booking creation
- Real-time conflict detection with existing bookings
- Show current renter info when conflicts occur
- Timezone validation for CET business hours

### **Real-time Updates**
- PubSub broadcasts for booking changes
- Live room availability updates
- Instant message notifications
- Live dashboard updates

### **File Upload System**
- Multiple photo uploads per room
- Primary photo selection
- Local file storage in `priv/static/uploads/rooms/`
- Image validation and processing

### **Communication System**
- User-to-user messaging with conversation threading
- Contact forms integrated with room booking views
- Unread message counters and notifications
- Message search and admin oversight


