import qrcode
import urllib.parse

# إعداد المعلومات
email = "qppv@gisipharmagroup.com"
subject = "بلاغ عن أعراض جانبية لدواء"
body = """
السادة فريق اليقظة الدوائية المحترمين،
أود الإبلاغ عن أعراض جانبية ظهرت بعد استخدامي للدواء التالي:
"""

# ترميز البيانات
subject_encoded = urllib.parse.quote(subject)
body_encoded = urllib.parse.quote(body)
mailto_link = f"mailto:{email}?subject={subject_encoded}&body={body_encoded}"

# إنشاء QR بحجم مخصص
qr = qrcode.QRCode(
    version=2,  # حجم أصغر من الافتراضي (1 = أصغر، 40 = أكبر)
    error_correction=qrcode.constants.ERROR_CORRECT_M,
    box_size=5,  # حجم كل مربع داخل الكود (تصغير الصورة)
    border=2     # عدد المربعات حول الكود
)

qr.add_data(mailto_link)
qr.make(fit=True)

img = qr.make_image(fill_color="black", back_color="white")
img.save("open_email_pharmacovigilance_qr_small.png")



import qrcode
import urllib.parse

# رقم الهاتف بصيغة دولية بدون +
phone_number = "201000911862"

# نص الرسالة (اختياري)
message = """
السلام عليكم،
أرغب في الإبلاغ عن أعراض جانبية لدواء.
"""
# ترميز الرسالة لتكون صالحة للرابط
encoded_message = urllib.parse.quote(message)

# رابط واتساب مع الرسالة
whatsapp_link = f"https://wa.me/{phone_number}?text={encoded_message}"

# إنشاء رمز QR
qr_img = qrcode.make(whatsapp_link)

# حفظ الصورة
qr_img.save("whatsapp_contact_qr.png")


import qrcode

# رابط التحميل (يمكن تغييره لأي رابط تريده)
url_1 = "https://drive.google.com/uc?export=download&id=1mBSu8urRKEABqXboSE_00Pr_v0ebaFVV"
url_2 = "https://drive.google.com/uc?export=download&id=1MJqQqB5GikMzRkumgbxnUwW5bdV7bTOj"
url_3 = "https://docs.google.com/forms/d/e/1FAIpQLSfJ2ElkJ-w_FzpVYa_XvIjKddoHFiMH0-IGxLFC7Yr5JS0pyA/viewform?pli=1"
url_4 = "https://docs.google.com/forms/d/e/1FAIpQLSfLfyFodjO8u6iiljsBNWdBA2ApND_ajXA9WeFTBlzsi53Z3Q/viewform"

# توليد رمز QR للرابط الأول
qr1 = qrcode.make(url_1)
qr1.save("download_file1_qr.png")

# توليد رمز QR للرابط الثاني
qr2 = qrcode.make(url_2)
qr2.save("download_file2_qr.png")

qr3 = qrcode.make(url_3)
qr3.save("fill_docs_arabic.png")

qr4 = qrcode.make(url_4)
qr4.save('fill_docs_eng.png')


