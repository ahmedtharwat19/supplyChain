print("Starting JSON validation...")

import json

# بيانات تجريبية
example_company = {
    "nameAr": "الشركة",
    "nameEn": "Company",
    "logoBase64": ""
}
example_vendor = {
    "name": "المورد",
    "company": "Vendor Co."
}
example_order = {
    "companyId": "c1",
    "supplierId": "v1",
    "supplierName": "المورد",
    "items": [{"name": "عنصر 1"}, {"name": "عنصر 2"}],
    "factoryIds": ["f1", "f2"],
    "createdAt": None  # يمكن تغييره لتاريخ كنص
}

try:
    json.dumps(example_company)
    json.dumps(example_vendor)
    json.dumps(example_order)
    print("✅ JSON structures are valid.")
except Exception as e:
    print(f"❌ Invalid JSON: {e}")
