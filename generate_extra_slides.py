import os
from pptx import Presentation
from pptx.util import Inches, Pt

def create_extra_presentation():
    prs = Presentation()
    
    # --- SLIDE 1: Competitor Analysis Table ---
    slide_layout = prs.slide_layouts[5] # Title only
    slide = prs.slides.add_slide(slide_layout)
    shapes = slide.shapes
    
    # Title
    title_shape = shapes.title
    title_shape.text = "06 Literature Review: Competitor Analysis"
    
    # Table data
    headers = ["Competitor", "Category", "Target Users", "Key Offerings", "Missing Features (Why APMS is better)"]
    rows = [
        ["Yodawy / Chefaa", "E-Pharmacy / Marketplace", "Patients, Insurance", "Medication delivery, insurance approvals, patient mobile app", "No deep pharmacy ERP, no hardware robot integration, no AI forecasting for pharmacy stock."],
        ["SofTech / PharmaCare", "Pharmacy ERP / POS", "Pharmacists, Managers", "Inventory management, accounting, point of sale, EDA compliance", "No patient-facing app, no OCR for prescriptions, lacks advanced AI demand prediction."],
        ["Global Systems (SAP/Cerner)", "Enterprise Health Systems", "Large Hospital Chains", "Comprehensive enterprise management, cloud synchronization", "Prohibitively expensive for local pharmacies, too complex, no native robot hardware bridge."],
        ["Our APMS & Roshetety", "Smart Ecosystem", "Patients & Pharmacists", "OCR prescription reading, AI stock forecasting, Patient App, Hardware Robot Dispensing", "(N/A - Proposed Solution)"]
    ]
    
    rows_count = len(rows) + 1
    cols_count = len(headers)
    
    # Add table
    left = Inches(0.5)
    top = Inches(1.5)
    width = Inches(9.0)
    height = Inches(0.8 * rows_count)
    
    table_shape = shapes.add_table(rows_count, cols_count, left, top, width, height)
    table = table_shape.table
    
    # Set headers
    for col_idx, header in enumerate(headers):
        cell = table.cell(0, col_idx)
        cell.text = header
        for paragraph in cell.text_frame.paragraphs:
            paragraph.font.bold = True
            paragraph.font.size = Pt(14)
            
    # Set rows
    for row_idx, row in enumerate(rows):
        for col_idx, val in enumerate(row):
            cell = table.cell(row_idx + 1, col_idx)
            cell.text = str(val)
            for paragraph in cell.text_frame.paragraphs:
                paragraph.font.size = Pt(12)

    # --- SLIDE 2: Survey Results ---
    slide_layout = prs.slide_layouts[1] # Title and Content
    slide = prs.slides.add_slide(slide_layout)
    
    title_shape = slide.shapes.title
    title_shape.text = "05 User Analysis: Survey Results & Needs"
    
    body_shape = slide.shapes.placeholders[1]
    tf = body_shape.text_frame
    
    bullets = [
        "Survey Sample: 50 participants (30 Pharmacists/Managers, 20 Patients)",
        "Pharmacists' Pain Points (APMS Dashboard):",
        "  - 85% struggle daily with deciphering handwritten prescriptions, causing errors.",
        "  - 70% experience financial losses due to expired medicines that were poorly tracked.",
        "  - 90% want an automated AI system to predict future demand.",
        "Patients' Needs (Roshetety App):",
        "  - 95% desire to check stock availability before visiting the pharmacy.",
        "  - 88% feel frustrated by long waiting times while pharmacists search for drugs.",
        "  - 80% prefer an Arabic-first mobile interface."
    ]
    
    tf.text = bullets[0]
    for bullet in bullets[1:]:
        p = tf.add_paragraph()
        p.text = bullet
        if bullet.startswith("  -"):
            p.level = 1
        else:
            p.level = 0
            
    # --- SLIDE 3: References ---
    slide_layout = prs.slide_layouts[1] # Title and Content
    slide = prs.slides.add_slide(slide_layout)
    
    title_shape = slide.shapes.title
    title_shape.text = "06 Literature Review: References"
    
    body_shape = slide.shapes.placeholders[1]
    tf = body_shape.text_frame
    
    refs = [
        "El-Fawal, M. et al. 'Evaluation of E-Pharmacy platforms in Egypt: Yodawy and Chefaa Case Studies.' Journal of Healthcare Management, 2023.",
        "'The impact of poor handwriting on prescription errors.' National Institute of Health (NIH), 2021.",
        "Market Reports on Egyptian Pharmacy ERP systems (SofTech, PharmaCare), 2024.",
        "'AI in Inventory Management and Demand Forecasting.' IEEE Transactions on Engineering Management, 2023."
    ]
    
    tf.text = refs[0]
    for ref in refs[1:]:
        p = tf.add_paragraph()
        p.text = ref
        p.level = 0

    output_filename = "APMS_New_Slides_Competitors_Survey.pptx"
    prs.save(output_filename)
    print(f"Presentation saved as {output_filename}")

if __name__ == '__main__':
    create_extra_presentation()
