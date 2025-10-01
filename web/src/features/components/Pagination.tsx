// components/Pagination.tsx
import React from "react";

interface PaginationProps {
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  showRange?: boolean; // optional: show "Page x of y"
}

const Pagination: React.FC<PaginationProps> = ({ currentPage, totalPages, onPageChange, showRange = true }) => {
  if (totalPages <= 1) return null;

  // produce a short windowed page list with ellipsis like typical UIs
  const pages: (number | string)[] = [];
  if (totalPages <= 7) {
    for (let i = 1; i <= totalPages; i++) pages.push(i);
  } else {
    // always show first, last, current ±1
    pages.push(1);
    if (currentPage > 3) pages.push("...");
    const start = Math.max(2, currentPage - 1);
    const end = Math.min(totalPages - 1, currentPage + 1);
    for (let i = start; i <= end; i++) pages.push(i);
    if (currentPage < totalPages - 2) pages.push("...");
    pages.push(totalPages);
  }

  return (
  <div className="pagination-wrapper">
    <div className="pagination" role="navigation" aria-label="Pagination">
      <button
        onClick={() => onPageChange(1)}
        disabled={currentPage === 1}
        aria-label="First page"
      >
        {"<<"}
      </button>

      <button
        onClick={() => onPageChange(Math.max(1, currentPage - 1))}
        disabled={currentPage === 1}
        aria-label="Previous page"
      >
        {"<"}
      </button>

      {pages.map((p, i) =>
        p === "..." ? (
          <span key={`ell-${i}`} className="dots">
            ...
          </span>
        ) : (
          <button
            key={p}
            className={p === currentPage ? "current" : ""}
            onClick={() => onPageChange(Number(p))}
            aria-current={p === currentPage ? "page" : undefined}
          >
            {p}
          </button>
        )
      )}

      <button
        onClick={() => onPageChange(Math.min(totalPages, currentPage + 1))}
        disabled={currentPage === totalPages}
        aria-label="Next page"
      >
        {">"}
      </button>

      <button
        onClick={() => onPageChange(totalPages)}
        disabled={currentPage === totalPages}
        aria-label="Last page"
      >
        {">>"}
      </button>
    </div>

    {showRange && (
      <div className="page-range">
        Page {currentPage} of {totalPages}
      </div>
    )}
  </div>
);
};

export default Pagination;
