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
    
    # Table data - Simplified for general audience
    headers = ["Competitor", "Category", "What They Offer", "What They Are Missing"]
    rows = [
        ["Yodawy / Chefaa", "Online Delivery Apps", "Medicine delivery, insurance approvals, patient app", "They don't manage the pharmacy from inside, no robot connection, no smart predictions."],
        ["Standard Software\n(SofTech, etc.)", "Basic Pharmacy Software", "Basic inventory, accounting, and cashier system", "No patient app, cannot read handwriting, no smart predictions for the future."],
        ["Global Systems\n(SAP/Cerner)", "Large Hospital Software", "Massive systems for huge hospital chains", "Very expensive, too complicated for normal pharmacies, no robot connection."],
        ["Our System\n(APMS & Roshetety)", "Smart & Complete System", "Patient App, Smart Robot, Reads Handwriting, Predicts Needs", "(Proposed Solution)"]
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
            paragraph.font.size = Pt(16)
            
    # Set rows
    for row_idx, row in enumerate(rows):
        for col_idx, val in enumerate(row):
            cell = table.cell(row_idx + 1, col_idx)
            cell.text = str(val)
            for paragraph in cell.text_frame.paragraphs:
                paragraph.font.size = Pt(14)

    # --- SLIDE 2: Survey Results ---
    slide_layout = prs.slide_layouts[1] # Title and Content
    slide = prs.slides.add_slide(slide_layout)
    
    title_shape = slide.shapes.title
    title_shape.text = "05 User Analysis: Survey Results"
    
    body_shape = slide.shapes.placeholders[1]
    tf = body_shape.text_frame
    
    bullets = [
        "Surveyed 50 people (30 Pharmacists, 20 Patients):",
        "Pharmacists' Main Problems:",
        "  - 85% struggle daily with reading bad handwriting on prescriptions.",
        "  - 70% lose money because medicines expire without anyone noticing.",
        "  - 90% need a smart system to tell them what medicines to buy next.",
        "Patients' Main Needs:",
        "  - 95% want to check if medicine is available before going to the pharmacy.",
        "  - 88% hate waiting for a long time while the pharmacist searches for the box.",
        "  - 80% want an easy-to-use Arabic application."
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
        "Market Reports on Egyptian Pharmacy Systems (SofTech, PharmaCare), 2024.",
        "'Using Smart Software to Predict Medicine Needs.' IEEE Transactions, 2023."
    ]
    
    tf.text = refs[0]
    for ref in refs[1:]:
        p = tf.add_paragraph()
        p.text = ref
        p.level = 0

    output_filename = "APMS_New_Slides_Simple.pptx"
    prs.save(output_filename)
    print(f"Presentation saved as {output_filename}")

if __name__ == '__main__':
    create_extra_presentation()
