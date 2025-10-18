// components/Pagination.tsx
import React, { useState, useRef, useEffect } from "react";

interface PaginationProps {
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  showRange?: boolean; // optional: show "Page x of y"
}

const Pagination: React.FC<PaginationProps> = ({ currentPage, totalPages, onPageChange, showRange = true }) => {
  const [showJumpInput, setShowJumpInput] = useState(false);
  const [inputValue, setInputValue] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (showJumpInput && inputRef.current) {
      inputRef.current.focus();
    }
  }, [showJumpInput]);

  const handleJump = () => {
    const page = Number(inputValue);
    if (page >= 1 && page <= totalPages) {
      onPageChange(page);
    }
    setShowJumpInput(false);
    setInputValue("");
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Enter") {
      handleJump();
    } else if (e.key === "Escape") {
      setShowJumpInput(false);
      setInputValue("");
    }
  };

  const handleBlur = () => {
    handleJump();
  };

  if (totalPages <= 1) return null;

  // Produce a short windowed page list with ellipsis like typical UIs
  const pages: (number | string)[] = [];
  const delta = 2;
  const rangeSize = 2 * delta + 1;

  if (totalPages <= 7) {
    for (let i = 1; i <= totalPages; i++) pages.push(i);
  } else {
    let left = Math.max(2, currentPage - delta);
    let right = Math.min(totalPages - 1, currentPage + delta);

    if (currentPage <= delta + 1) {
      right = Math.min(totalPages - 1, 2 * (delta + 1));
    } else if (currentPage >= totalPages - delta) {
      left = Math.max(2, totalPages - 2 * (delta + 1));
    }

    pages.push(1);

    if (left > 2) {
      pages.push("...");
    }

    for (let i = left; i <= right; i++) {
      pages.push(i);
    }

    if (right < totalPages - 1) {
      pages.push("...");
    }

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
            <button
              key={`ell-${i}`}
              className="dots"
              onClick={() => setShowJumpInput(true)}
              aria-label="Jump to specific page"
            >
              ...
            </button>
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

        {showJumpInput && (
          <span className="page-jump">
            <input
              ref={inputRef}
              type="number"
              min={1}
              max={totalPages}
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              onKeyDown={handleKeyDown}
              onBlur={handleBlur}
              placeholder="Go to..."
              aria-label="Jump to page"
            />
          </span>
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