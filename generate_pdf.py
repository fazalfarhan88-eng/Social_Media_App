from fpdf import FPDF
import re

class PDF(FPDF):
    def chapter_body(self, body):
        self.set_font('Arial', '', 11)
        # Replace unsupported characters (like emojis) with a space or standard ascii
        clean_body = body.encode('latin-1', 'ignore').decode('latin-1')
        self.multi_cell(0, 6, clean_body)
        self.ln()

pdf = PDF()
pdf.add_page()
pdf.set_font('Arial', 'B', 16)
pdf.cell(0, 10, "Social Media App - Project Documentation", 0, 1, 'C')
pdf.ln(10)

with open('e:/Social_Media_App/Project_Documentation.md', 'r', encoding='utf-8') as f:
    text = f.read()

pdf.chapter_body(text)
pdf.output('e:/Social_Media_App/Project_Documentation.pdf')
print("PDF Generated!")
