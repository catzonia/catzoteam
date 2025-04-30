import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

class ShopScreen extends StatefulWidget {
  final String selectedBranchCode;

  const ShopScreen({required this.selectedBranchCode, Key? key}) : super(key: key);

  @override
  _ShopScreenState createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String _selectedMode = "Grooming";
  int _selectedCategoryIndex = 0;
  double _totalPrice = 0.00;

  final List<String> _categories = ["Beauty", "Wellness", "CatzoSpa+", "Lion Cut"];

  final Map<String, List<Map<String, dynamic>>> _categoryItems = {
    "Beauty": [
      {"name": "Black Monster", "price": 90},
      {"name": "Collagen Essence Bath", "price": 100},
      {"name": "Fluffy White", "price": 90},
      {"name": "Royal Splash", "price": 140},
      {"name": "VIC Grooming", "price": 140},
    ],
    "Wellness": [
      {"name": "Aromatic Salt Bath", "price": 140},
      {"name": "De-Flea Treatment", "price": 110},
      {"name": "Medi-Cat Bath", "price": 120},
      {"name": "Oatmeal Scrub", "price": 130},
      {"name": "Ozone Bath", "price": 140},
      {"name": "Sea Mud Treatment", "price": 150},
    ],
    "CatzoSpa+": [
      {"name": "MagnifiScent Splash", "price": 160},
      {"name": "Skinsational Bath", "price": 170},
      {"name": "Smitten Scrub", "price": 180},
      {"name": "Supreme Flea Treatment", "price": 150},
      {"name": "Sweet Bee Scrub", "price": 180},
    ],
    "Lion Cut": [
      {"name": "Lion Cut with Procedure", "price": 160},
      {"name": "Lion Cut Standard", "price": 200},
      {"name": "Lion Cut Spa", "price": 230},
    ],
  };

  final Map<String, Map<String, int>> _groomingSlots = {};

  DateTime? _checkInDate;
  DateTime? _checkOutDate;

  final Map<String, Map<String, dynamic>> _branchData = {
    "BG": {
      "name": "Bangi",
      "slots": [
        {"id": "Economy", "capacity": 5, "booked": <String, int>{}, "price": 35},
        {"id": "Comfy", "capacity": 10, "booked": <String, int>{}, "price": 50},
        {"id": "VIC", "capacity": 8, "booked": <String, int>{}, "price": 70},
        {"id": "VVIC", "capacity": 8, "booked": <String, int>{}, "price": 100},
        {"id": "Super VIC", "capacity": 1, "booked": <String, int>{}, "price": 150},
      ],
    },
    "DP": {
      "name": "Damansara Perdana",
      "slots": [
        {"id": "Economy", "capacity": 5, "booked": <String, int>{}, "price": 35},
        {"id": "Comfy", "capacity": 10, "booked": <String, int>{}, "price": 50},
        {"id": "VIC", "capacity": 8, "booked": <String, int>{}, "price": 70},
        {"id": "VVIC", "capacity": 8, "booked": <String, int>{}, "price": 100},
        {"id": "Super VIC", "capacity": 1, "booked": <String, int>{}, "price": 150},
      ],
    },
  };

  late Map<String, dynamic> _selectedBranch;

  String? _selectedCustomer;
  String? _selectedCat;

  final Map<String, Map<String, CatCartEntry>> _cart = {};
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredItems = [];

  final Map<String, List<String>> _customerCats = {
    "Jane Doe": ["Kiki", "Lala"],
    "John Harbor": ["Mimi", "Nono"],
    "Alice Johnson": ["Whiskers"],
    "Bob Brown": ["Tiger", "Leo"],
  };

  int _orderIdCounter = 7;

  @override
  void initState() {
    super.initState();
    _filteredItems = _categoryItems[_categories[_selectedCategoryIndex]]!
        .map((item) => {
              "name": item["name"],
              "price": item["price"],
              "category": _categories[_selectedCategoryIndex],
            })
        .toList();
    _searchController.addListener(_filterItems);
    _selectedBranch = _branchData[widget.selectedBranchCode] ?? _branchData["DP"]!;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    setState(() {
      String query = _searchController.text.toLowerCase();
      if (query.isEmpty) {
        _filteredItems = _categoryItems[_categories[_selectedCategoryIndex]]!
            .map((item) => {
                  "name": item["name"],
                  "price": item["price"],
                  "category": _categories[_selectedCategoryIndex],
                })
            .toList();
      } else {
        _filteredItems = [];
        Map<String, int> categoryMatchCount = {};

        _categoryItems.forEach((category, items) {
          int matches = 0;
          for (var item in items) {
            if (item["name"].toLowerCase().contains(query)) {
              _filteredItems.add({
                "name": item["name"],
                "price": item["price"],
                "category": category,
              });
              matches++;
            }
          }
          categoryMatchCount[category] = matches;
        });

        if (_filteredItems.isNotEmpty) {
          String? mostMatchedCategory;
          int maxMatches = 0;

          categoryMatchCount.forEach((category, count) {
            if (count > maxMatches) {
              maxMatches = count;
              mostMatchedCategory = category;
            }
          });

          if (mostMatchedCategory != null) {
            int newIndex = _categories.indexOf(mostMatchedCategory!);
            if (newIndex != -1 && newIndex != _selectedCategoryIndex) {
              _selectedCategoryIndex = newIndex;
            }
          }
        }
      }
    });
  }

  void _selectCustomer() {
    List<String> customers = _customerCats.keys.toList();
    List<String> filteredCustomers = List.from(customers);
    TextEditingController customerSearchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              title: const Text("Select Customer", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: customerSearchController,
                        decoration: InputDecoration(
                          hintText: "Search customer...",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                          suffixIcon: customerSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                                  onPressed: () {
                                    customerSearchController.clear();
                                    setDialogState(() => filteredCustomers = List.from(customers));
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            filteredCustomers = customers.where((customer) => customer.toLowerCase().contains(value.toLowerCase())).toList();
                          });
                        },
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 200, // Fixed height for the list
                        child: filteredCustomers.isEmpty
                            ? const Center(child: Text("No customers found", style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: filteredCustomers.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    leading: const Icon(Icons.person_rounded, color: Colors.orange),
                                    title: Text(filteredCustomers[index], style: const TextStyle(fontSize: 16, color: Colors.black87)),
                                    onTap: () {
                                      setState(() {
                                        _selectedCustomer = filteredCustomers[index];
                                        _selectedCat = null;
                                        _cart.clear();
                                        _totalPrice = 0.00;
                                      });
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddCustomerDialog();
                        },
                        icon: const Icon(Icons.add_rounded, color: Colors.orange),
                        label: const Text("Add New Customer", style: TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddCustomerDialog() {
    TextEditingController newCustomerController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: const Text("Add New Customer", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: newCustomerController,
              decoration: InputDecoration(
                hintText: "Enter customer name",
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontSize: 16))),
            ElevatedButton(
              onPressed: () {
                if (newCustomerController.text.isNotEmpty) {
                  setState(() {
                    _customerCats[newCustomerController.text] = [];
                    _selectedCustomer = newCustomerController.text;
                    _selectedCat = null;
                    _cart.clear();
                    _totalPrice = 0.00;
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a customer name"), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text("Add", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  void _addService(String service, String category) async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a customer")));
      return;
    }

    Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => GroomingBookingDialog(
        service: service,
        category: category,
        groomingSlots: _groomingSlots,
        categoryItems: _categoryItems,
        availableCats: _customerCats[_selectedCustomer!] ?? [],
      ),
    );

    if (result == null) return;

    String selectedCat = result["cat"]!;
    String dateKey = result["date"]!;
    String selectedTime = result["time"]!;

    if (_groomingSlots[dateKey]![selectedTime]! > 0) {
      setState(() {
        _groomingSlots[dateKey]![selectedTime] = _groomingSlots[dateKey]![selectedTime]! - 1;

        _cart.putIfAbsent(_selectedCustomer!, () => {});
        _cart[_selectedCustomer!]!.putIfAbsent(selectedCat, () => CatCartEntry(orderId: "ORD-00$_orderIdCounter", services: []));

        if (_cart[_selectedCustomer!]![selectedCat]!.services.isEmpty) {
          _orderIdCounter++;
        }

        _cart[_selectedCustomer!]![selectedCat]!.services.add({
          "service": service,
          "category": category,
          "type": "grooming",
          "date": dateKey,
          "time": selectedTime,
        });

        _selectedCat = selectedCat;
        double price = _categoryItems[category]!.firstWhere((item) => item["name"] == service)["price"].toDouble();
        _totalPrice += price;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$service at $selectedTime on $dateKey added to cart!")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selected time slot is fully booked")));
    }
  }

  void _addBoarding(String branch, String slotId, double pricePerNight) async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a customer")));
      return;
    }

    Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => BoardingBookingDialog(
        branch: branch,
        slotId: slotId,
        pricePerNight: pricePerNight,
        checkInDate: _checkInDate!,
        checkOutDate: _checkOutDate!,
        bookedSlots: _selectedBranch["slots"].firstWhere((s) => s["id"] == slotId)["booked"],
        capacity: _selectedBranch["slots"].firstWhere((s) => s["id"] == slotId)["capacity"],
        availableCats: _customerCats[_selectedCustomer!] ?? [],
      ),
    );

    if (result == null) return;

    String selectedCat = result["cat"]!;
    String checkIn = result["checkIn"]!;
    String checkOut = result["checkOut"]!;
    String carrierType = result["carrierType"]!;
    String carrierRemark = result["carrierRemark"]!;
    String itemsRemark = result["itemsRemark"]!;
    int nights = result["nights"]!;
    List<String> bookedDates = List.generate(
      nights,
      (index) => DateFormat('dd MMM yyyy').format(
      DateFormat('dd MMM yyyy').parse(checkIn).add(Duration(days: index))
      ),
    );

    setState(() {
      var slot = _selectedBranch["slots"].firstWhere((s) => s["id"] == slotId);
      for (String date in bookedDates) {
        slot["booked"][date] = (slot["booked"][date] ?? 0) + 1;
      }

      _cart.putIfAbsent(_selectedCustomer!, () => {});
      _cart[_selectedCustomer!]!.putIfAbsent(selectedCat, () => CatCartEntry(orderId: "ORD-00$_orderIdCounter", services: []));

      if (_cart[_selectedCustomer!]![selectedCat]!.services.isEmpty) {
        _orderIdCounter++;
      }

      _cart[_selectedCustomer!]![selectedCat]!.services.add({
        "branch": branch,
        "slotId": slotId,
        "checkIn": checkIn,
        "checkOut": checkOut,
        "carrierType": carrierType,
        "carrierRemark": carrierRemark,
        "itemsRemark": itemsRemark,
        "type": "boarding",
        "nights": nights,
      });
      
      _selectedCat = selectedCat;
      _totalPrice += pricePerNight * nights;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$slotId at $branch booked for $nights night(s)!")));
  }

  void _selectDates(BuildContext context) async {
  DateTime firstFocusDay = DateTime.now();
  DateTime secondFocusDay = DateTime.now().add(const Duration(days: 30));
  DateTime? pickedCheckIn;
  DateTime? pickedCheckOut;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(0),
            content: SizedBox(
              width: 800,
              height: 400,
              child: Row(
                children: [
                  Expanded(
                    child: TableCalendar(
                      firstDay: DateTime.now(),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: firstFocusDay,
                      calendarFormat: CalendarFormat.month,
                      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                      headerStyle: const HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false, 
                      ),
                      calendarStyle: const CalendarStyle(
                        outsideDaysVisible: false, 
                        todayDecoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(BorderSide(color: Colors.orange, width: 1)),
                          color: Colors.transparent,
                        ),
                        todayTextStyle: TextStyle(
                          color: Colors.orange,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      selectedDayPredicate: (day) => pickedCheckIn != null && isSameDay(day, pickedCheckIn),
                      onDaySelected: (selectedDay, focusedDay) {
                        setDialogState(() {
                          pickedCheckIn = selectedDay;
                          firstFocusDay = focusedDay;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: TableCalendar(
                      firstDay: DateTime.now(),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: secondFocusDay,
                      calendarFormat: CalendarFormat.month,
                      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                      headerStyle: const HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                      ),
                      calendarStyle: const CalendarStyle(
                        outsideDaysVisible: false, 
                        todayDecoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(BorderSide(color: Colors.orange, width: 1)),
                          color: Colors.transparent,
                        ),
                        todayTextStyle: TextStyle(
                          color: Colors.orange,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      selectedDayPredicate: (day) => pickedCheckOut != null && isSameDay(day, pickedCheckOut),
                      onDaySelected: (selectedDay, focusedDay) {
                        setDialogState(() {
                          pickedCheckOut = selectedDay;
                          secondFocusDay = focusedDay;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  if (pickedCheckIn != null && pickedCheckOut != null) {
                    setState(() {
                      _checkInDate = pickedCheckIn;
                      _checkOutDate = pickedCheckOut;
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text("Confirm"),
              ),
            ],
          );
        },
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedMode,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black),
                              dropdownColor: Colors.white,
                              items: ["Grooming", "Boarding"].map((mode) => DropdownMenuItem(value: mode, child: Text(mode, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)))).toList(),
                              onChanged: (value) => setState(() => _selectedMode = value!),
                            ),
                          ),
                        ),
                        const Spacer(),
                        _selectedMode == "Grooming"
                            ? Container(
                                width: 300,
                                height: 45,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: "Search services...",
                                    hintStyle: TextStyle(color: Colors.grey[800]),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.orange, width: 2)),
                                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[600]),
                                    suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: Icon(Icons.clear_rounded, color: Colors.grey[600]), onPressed: () => {_searchController.clear(), _filterItems()}) : null,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  Container(
                                    width: 300,
                                    height: 45,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(icon: Icon(Icons.calendar_month_rounded, color: Colors.grey[600]), onPressed: () => _selectDates(context)),
                                        const SizedBox(width: 10),
                                        Text(
                                          _checkInDate != null && _checkOutDate != null
                                              ? "${DateFormat('dd MMM').format(_checkInDate!)} - ${DateFormat('dd MMM yyyy').format(_checkOutDate!)}"
                                              : "Select Dates",
                                          style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_selectedMode == "Grooming") _buildCategory(),
                    const SizedBox(height: 10),
                    _selectedMode == "Grooming" ? _buildServices() : _buildRooms(),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              _buildBill(),
            ],
          ),
        ),

        // Blur and overlay
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
              child: Container(
                color: Colors.white.withOpacity(0.7),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.store_rounded, size: 80, color: Colors.deepOrange),
                    SizedBox(height: 16),
                    Text(
                      'Shop Coming Soon',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'We’re working hard to launch this feature!',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategory() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_categories.length, (index) {
          bool isSelected = _selectedCategoryIndex == index;
          return Container(
            width: 150,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryIndex = index;
                  _searchController.clear();
                  _filteredItems = _categoryItems[_categories[_selectedCategoryIndex]]!.map((item) => {"name": item["name"], "price": item["price"], "category": _categories[_selectedCategoryIndex]}).toList();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected ? const LinearGradient(colors: [Colors.orange, Colors.deepOrange]) : const LinearGradient(colors: [Colors.white, Colors.white]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: isSelected ? Colors.orange.withOpacity(0.4) : Colors.black12, blurRadius: 8, spreadRadius: 2, offset: const Offset(0, 4))],
                ),
                child: Center(
                  child: Text(_categories[index], textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildServices() {
    return Expanded(
      child: GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.75),
        itemCount: _filteredItems.length,
        itemBuilder: (context, index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2, offset: const Offset(0, 4))]),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 140,
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), image: const DecorationImage(image: NetworkImage('https://via.placeholder.com/150'), fit: BoxFit.cover)),
                    ),
                    const SizedBox(height: 12),
                    Text(_filteredItems[index]["name"], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    Text("RM ${(_filteredItems[index]["price"]).toStringAsFixed(2)}", style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: IconButton(
                        icon: const Icon(Icons.add_circle_rounded, color: Colors.orange, size: 40),
                        onPressed: () => _addService(_filteredItems[index]["name"], _filteredItems[index]["category"]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRooms() {
    if (_checkInDate == null || _checkOutDate == null) {
      return const Center(
        child: Text(
          "Please select Check-In and Check-Out dates",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Expanded(
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1),
        itemCount: _selectedBranch["slots"].length,
        itemBuilder: (context, slotIndex) {
          var slot = _selectedBranch["slots"][slotIndex];
          
          // Check availability across the whole stay
          bool isAvailable = true;
          if (_checkInDate != null && _checkOutDate != null) {
            for (int i = 0; i < _checkOutDate!.difference(_checkInDate!).inDays; i++) {
              String dateKey = DateFormat('dd MMM yyyy').format(_checkInDate!.add(Duration(days: i)));
              int booked = slot["booked"][dateKey] ?? 0;
              if (booked >= slot["capacity"]) {
                isAvailable = false;
                break;
              }
            }
          }

          // Check if this slot is already selected for this customer and cat
          bool isSelected = _cart[_selectedCustomer]?[_selectedCat]?.services.any((entry) =>
              entry["type"] == "boarding" &&
              entry["branch"] == _selectedBranch["name"] &&
              entry["slotId"] == slot["id"] &&
              entry["checkIn"] == DateFormat('dd MMM yyyy').format(_checkInDate!)) ?? false;

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: isAvailable ? () => _addBoarding(_selectedBranch["name"], slot["id"], slot["price"].toDouble()) : null,
                child: Container(
                  decoration: BoxDecoration(color: isSelected ? Colors.orange : (isAvailable ? Colors.green[100] : Colors.grey[300]), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(slot["id"], style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                      Text("RM ${slot["price"]}/night", style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12)),
                      Text("${slot["capacity"]} rooms", style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBill() {
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _selectCustomer,
                child: Text(
                  _selectedCustomer ?? "Select Customer",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (_selectedCustomer != null)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Colors.red),
                  onPressed: () => setState(() {
                    _selectedCustomer = null;
                    _selectedCat = null;
                    _cart.clear();
                    _totalPrice = 0.00;
                    _orderIdCounter = 7;
                  }),
                ),
            ],
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedCustomer != null && _cart.containsKey(_selectedCustomer))
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _cart[_selectedCustomer!]!.entries.length,
                          itemBuilder: (context, index) {
                            final catEntry = _cart[_selectedCustomer!]!.entries.elementAt(index);
                            bool isSelected = catEntry.key == _selectedCat;
                            String orderId = catEntry.value.orderId;
                            List<Map<String, dynamic>> services = catEntry.value.services;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedCat = catEntry.key),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.orange.withOpacity(0.1) : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected ? Colors.orange : Colors.grey[300]!,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.pets_rounded,
                                          size: 18,
                                          color: isSelected ? Colors.orange : Colors.black87,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "${catEntry.key} ($orderId)",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.orange : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...services.asMap().entries.map((serviceEntry) {
                                      int idx = serviceEntry.key;
                                      Map<String, dynamic> cartItem = serviceEntry.value;
                                      if (cartItem["type"] == "grooming") {
                                        String service = cartItem["service"]!;
                                        String category = cartItem["category"]!;
                                        String date = cartItem["date"]!;
                                        String time = cartItem["time"]!;
                                        return Padding(
                                          padding: const EdgeInsets.only(left: 16.0, top: 6),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.check_circle_rounded,
                                                size: 20,
                                                color: Colors.orange,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  "$service ($date, $time)",
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_rounded,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    double price = _categoryItems[category]!
                                                        .firstWhere((item) => item["name"] == service)["price"]
                                                        .toDouble();
                                                    _groomingSlots[date]![time] = _groomingSlots[date]![time]! + 1;
                                                    _cart[_selectedCustomer!]![catEntry.key]!.services.removeAt(idx);
                                                    _totalPrice -= price;
                                                    if (_cart[_selectedCustomer!]![catEntry.key]!.services.isEmpty) {
                                                      _cart[_selectedCustomer!]!.remove(catEntry.key);
                                                      if (_selectedCat == catEntry.key) _selectedCat = null;
                                                    }
                                                    if (_cart[_selectedCustomer!]!.isEmpty) _cart.remove(_selectedCustomer);
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      } else {
                                        String slotId = cartItem["slotId"]!;
                                        String checkIn = cartItem["checkIn"]!;
                                        String checkOut = cartItem["checkOut"]!;
                                        String carrierType = cartItem["carrierType"]!;
                                        String carrierRemark = cartItem["carrierRemark"]!;
                                        String itemsRemark = cartItem["itemsRemark"]!;
                                        int nights = cartItem["nights"]!;
                                        double pricePerNight = _selectedBranch["slots"]
                                            .firstWhere((s) => s["id"] == slotId)["price"]
                                            .toDouble();

                                        return Padding(
                                          padding: const EdgeInsets.only(left: 16.0, top: 6),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.check_circle_rounded,
                                                    size: 20,
                                                    color: Colors.orange,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      "$slotId ($checkIn - $checkOut)",
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete_rounded,
                                                      color: Colors.red,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      setState(() {
                                                        List<String> bookedDates = List.generate(
                                                          nights,
                                                          (i) => DateFormat('dd MMM yyyy')
                                                              .format(DateTime.parse(checkIn).add(Duration(days: i))),
                                                        );
                                                        for (String date in bookedDates) {
                                                          var slot = _selectedBranch["slots"]
                                                              .firstWhere((s) => s["id"] == slotId);
                                                          slot["booked"][date] = (slot["booked"][date] ?? 0) - 1;
                                                        }
                                                        _cart[_selectedCustomer!]![catEntry.key]!.services.removeAt(idx);
                                                        _totalPrice -= pricePerNight * nights;
                                                        if (_cart[_selectedCustomer!]![catEntry.key]!.services.isEmpty) {
                                                          _cart[_selectedCustomer!]!.remove(catEntry.key);
                                                          if (_selectedCat == catEntry.key) _selectedCat = null;
                                                        }
                                                        if (_cart[_selectedCustomer!]!.isEmpty) _cart.remove(_selectedCustomer);
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(left: 28.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "Carrier: $carrierType${carrierRemark.isNotEmpty ? ' ($carrierRemark)' : ''}",
                                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    ),
                                                    if (itemsRemark.isNotEmpty)
                                                      Text(
                                                        "Items: $itemsRemark",
                                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                      ),
                                                    Text(
                                                      "Total: RM ${(pricePerNight * nights).toStringAsFixed(2)} ($nights nights)",
                                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    }).toList(),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total: RM ${_totalPrice.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_cart.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    _cart.clear();
                    _selectedCat = null;
                    _totalPrice = 0.00;
                    _orderIdCounter = 7;
                  }),
                  child: const Text(
                    "Clear Cart",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: _totalPrice > 0
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Checkout successful!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() {
                      _cart.clear();
                      _selectedCat = null;
                      _totalPrice = 0.00;
                      _orderIdCounter = 7;
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Center(
              child: Text(
                "Checkout",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CatCartEntry {
  String orderId;
  List<Map<String, dynamic>> services;

  CatCartEntry({required this.orderId, required this.services});
}

class GroomingBookingDialog extends StatefulWidget {
  final String service;
  final String category;
  final Map<String, Map<String, int>> groomingSlots;
  final Map<String, List<Map<String, dynamic>>> categoryItems;
  final List<String> availableCats;

  const GroomingBookingDialog({
    required this.service,
    required this.category,
    required this.groomingSlots,
    required this.categoryItems,
    required this.availableCats,
    Key? key,
  }) : super(key: key);

  @override
  _GroomingBookingDialogState createState() => _GroomingBookingDialogState();
}

class _GroomingBookingDialogState extends State<GroomingBookingDialog> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  String? _selectedCat;

  @override
  Widget build(BuildContext context) {
    String dateKey = DateFormat('dd MMM yyyy').format(_selectedDate);
    widget.groomingSlots.putIfAbsent(dateKey, () => {"10 AM": 3, "12 PM": 3, "2 PM": 3});
    double price = widget.categoryItems[widget.category]!
        .firstWhere((item) => item["name"] == widget.service)["price"]
        .toDouble();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: const Text(
        "Book Grooming Service", 
        style: TextStyle(fontSize: 20, 
        fontWeight: FontWeight.bold, 
        color: Colors.black87)
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [              
              const Text("Service Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 10),
              Text("Service: ${widget.service}", style: const TextStyle(fontSize: 14, color: Colors.black87)),
              Text("Category: ${widget.category}", style: const TextStyle(fontSize: 14, color: Colors.black87)),
              Text("Price: RM ${price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, color: Colors.black87)),
              const Divider(height: 20),

              const Text("Cat", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.only(left: 5),
                child: ElevatedButton(
                  onPressed: _selectCatInsideDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  ),
                  child: Text(_selectedCat ?? "Select Cat"),
                ),
              ),
              const Divider(height: 20),

              const Text("Date", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 10),
              Container(
                height: 200,
                child: CalendarDatePicker(
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onDateChanged: (date) {
                    setState(() {
                      _selectedDate = date;
                      _selectedTime = null;
                    });
                  },
                ),
              ),
              const Divider(height: 20),

              const Text("Time Slot", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: ["10 AM", "12 PM", "2 PM"].map((time) {
                  int remaining = widget.groomingSlots[dateKey]![time]!;
                  bool isSelected = _selectedTime == time;
                  return ChoiceChip(
                    label: Text("$time ($remaining left)", style: TextStyle(color: isSelected ? Colors.white : Colors.black87)),
                    selected: isSelected,
                    selectedColor: Colors.orange,
                    backgroundColor: remaining > 0 ? Colors.grey[200] : Colors.grey[400],
                    onSelected: remaining > 0
                        ? (selected) {
                            setState(() => _selectedTime = selected ? time : null);
                          }
                        : null,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
        ElevatedButton(
          onPressed: _selectedCat != null && _selectedTime != null
              ? () {
                  Navigator.pop(context, {
                    "cat": _selectedCat,
                    "date": dateKey,
                    "time": _selectedTime!,
                  });
                }
              : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text("Book", style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }

  void _selectCatInsideDialog() {
    List<String> cats = widget.availableCats;
    List<String> filteredCats = List.from(cats);
    TextEditingController catSearchController = TextEditingController();
    TextEditingController newCatController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              title: const Text("Select Cat", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    children: [
                      TextField(
                        controller: catSearchController,
                        decoration: InputDecoration(
                          hintText: "Search cat...",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            filteredCats = cats.where((cat) => cat.toLowerCase().contains(value.toLowerCase())).toList();
                          });
                        },
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 200,
                        child: filteredCats.isEmpty
                            ? const Center(child: Text("No cats found", style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: filteredCats.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    leading: const Icon(Icons.pets_rounded, color: Colors.orange),
                                    title: Text(filteredCats[index]),
                                    onTap: () {
                                      setState(() => _selectedCat = filteredCats[index]);
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text("Add New Cat"),
                                content: TextField(
                                  controller: newCatController,
                                  decoration: const InputDecoration(hintText: "Enter cat name"),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (newCatController.text.isNotEmpty) {
                                        setState(() {
                                          widget.availableCats.add(newCatController.text);
                                          _selectedCat = newCatController.text;
                                        });
                                        Navigator.pop(context); 
                                        Navigator.pop(context); 
                                      }
                                    },
                                    child: const Text("Add"),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.add_rounded, color: Colors.orange),
                        label: const Text("Add New Cat", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ],
            );
          },
        );
      },
    );
  }
}

class BoardingBookingDialog extends StatefulWidget {
  final String branch;
  final String slotId;
  final double pricePerNight;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final Map<String, int> bookedSlots;
  final int capacity;
  final List<String> availableCats;

  const BoardingBookingDialog({
    required this.branch,
    required this.slotId,
    required this.pricePerNight,
    required this.checkInDate,
    required this.checkOutDate,
    required this.bookedSlots,
    required this.capacity,
    required this.availableCats,
    Key? key,
  }) : super(key: key);

  @override
  _BoardingBookingDialogState createState() => _BoardingBookingDialogState();
}

class _BoardingBookingDialogState extends State<BoardingBookingDialog> {
  String? _carrierType;
  String? _selectedCat;
  final TextEditingController _carrierRemarkController = TextEditingController();
  final TextEditingController _itemsRemarkController = TextEditingController();
  final List<String> _carrierTypes = ["Backpack Bag", "Hand Carry Bag", "Stroller", "Carriage Box", "Others"];

  bool _isSlotAvailable(List<String> dates) {
    for (String date in dates) {
      widget.bookedSlots.putIfAbsent(date, () => 0);
      if (widget.bookedSlots[date]! >= widget.capacity) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    String checkInKey = DateFormat('dd MMM yyyy').format(widget.checkInDate);
    String checkOutKey = DateFormat('dd MMM yyyy').format(widget.checkOutDate);
    int nights = widget.checkOutDate.difference(widget.checkInDate).inDays;
    List<String> bookedDates = List.generate(nights, (index) => DateFormat('dd MMM yyyy').format(widget.checkInDate.add(Duration(days: index))));
    bool isAvailable = _isSlotAvailable(bookedDates);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: const Text("Book Boarding Service", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Room Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 10),
              Text("Branch: ${widget.branch}", style: const TextStyle(fontSize: 14, color: Colors.black87)),
              Text("Room: ${widget.slotId}", style: const TextStyle(fontSize: 14, color: Colors.black87)),
              Text("Price: RM ${widget.pricePerNight.toStringAsFixed(2)}/night", style: const TextStyle(fontSize: 14, color: Colors.black87)),
              const Divider(height: 20),
              
              const Text("Stay Duration", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text("Check-In: $checkInKey", style: const TextStyle(fontSize: 14, color: Colors.black87)),
              Text("Check-Out: $checkOutKey", style: const TextStyle(fontSize: 14, color: Colors.black87)),
              Text("Total Nights: $nights", style: const TextStyle(fontSize: 14, color: Colors.black87)),
              const Divider(height: 20),

              const Text("Cat", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.only(left: 5),
                child: ElevatedButton(
                  onPressed: _selectCatInsideDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  ),
                  child: Text(_selectedCat ?? "Select Cat"),
                ),
              ),
              const Divider(height: 20),
              
              const Text("Carrier Type", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _carrierType,
                hint: const Text("Select Carrier Type"),
                items: _carrierTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (value) => setState(() => _carrierType = value),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const Divider(height: 20),

              const Text("Carrier Remark", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 10),
              TextField(
                controller: _carrierRemarkController,
                decoration: InputDecoration(
                  hintText: "Color, size, etc.",
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const Divider(height: 20),

              const Text("Additional Items", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 10),
              TextField(
                controller: _itemsRemarkController,
                decoration: InputDecoration(
                  hintText: "Toys, mats, etc.",
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
        ElevatedButton(
          onPressed: _carrierType != null && isAvailable
              ? () {
                  Navigator.pop(context, {
                    "cat": _selectedCat!,
                    "checkIn": checkInKey,
                    "checkOut": checkOutKey,
                    "carrierType": _carrierType!,
                    "carrierRemark": _carrierRemarkController.text,
                    "itemsRemark": _itemsRemarkController.text,
                    "nights": nights,
                  });
                }
              : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text("Book", style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }

  void _selectCatInsideDialog() {
    List<String> cats = widget.availableCats;
    List<String> filteredCats = List.from(cats);
    TextEditingController catSearchController = TextEditingController();
    TextEditingController newCatController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              title: const Text("Select Cat", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    children: [
                      TextField(
                        controller: catSearchController,
                        decoration: InputDecoration(
                          hintText: "Search cat...",
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            filteredCats = cats.where((cat) => cat.toLowerCase().contains(value.toLowerCase())).toList();
                          });
                        },
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 200,
                        child: filteredCats.isEmpty
                            ? const Center(child: Text("No cats found", style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: filteredCats.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    leading: const Icon(Icons.pets_rounded, color: Colors.orange),
                                    title: Text(filteredCats[index]),
                                    onTap: () {
                                      setState(() => _selectedCat = filteredCats[index]);
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text("Add New Cat"),
                                content: TextField(
                                  controller: newCatController,
                                  decoration: const InputDecoration(hintText: "Enter cat name"),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (newCatController.text.isNotEmpty) {
                                        setState(() {
                                          widget.availableCats.add(newCatController.text);
                                          _selectedCat = newCatController.text;
                                        });
                                        Navigator.pop(context); // Close Add Cat dialog
                                        Navigator.pop(context); // Close Select Cat dialog
                                      }
                                    },
                                    child: const Text("Add"),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.add_rounded, color: Colors.orange),
                        label: const Text("Add New Cat", style: TextStyle(color: Colors.orange)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ],
            );
          },
        );
      },
    );
  }
}